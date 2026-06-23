import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Result of saving a tune: the local file (used as the share source / fallback)
/// and a human-friendly location to show the user.
class TuneSaveResult {
  final String filePath;
  final String displayLocation;
  const TuneSaveResult(this.filePath, this.displayLocation);
}

/// Saves a rendered tune (WAV bytes) to local storage.
///
/// Always writes a private copy (used for sharing), and on Android also publishes
/// it into the shared **Music/Xylophone** folder via the platform's official
/// MediaStore API (see MainActivity) — no third-party plugin, no permission on
/// Android 10+.
class TuneExporter {
  static const MethodChannel _channel = MethodChannel('xylophone/storage');

  static Future<TuneSaveResult> save(Uint8List wav) async {
    final dir = await _privateDir();
    final name = 'tune_${_timestamp()}.wav';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(wav, flush: true);

    var location = 'XylophoneTunes (app files)';
    if (Platform.isAndroid) {
      try {
        final published = await _channel.invokeMethod<String>(
          'saveAudioToMusic',
          {'bytes': wav, 'fileName': name},
        );
        if (published != null) location = published;
      } catch (_) {
        // Older devices / failure: keep the private-copy fallback.
      }
    }
    return TuneSaveResult(file.path, location);
  }

  static Future<Directory> _privateDir() async {
    Directory base;
    if (Platform.isAndroid) {
      base = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } else {
      base = await getApplicationDocumentsDirectory();
    }
    final dir = Directory('${base.path}/XylophoneTunes');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _timestamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_'
        '${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }
}
