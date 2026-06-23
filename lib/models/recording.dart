import 'dart:convert';

import 'note.dart';

/// A single tap captured during recording.
class RecordedHit {
  final int noteIndex; // 0..6
  final Octave octave;
  final int atMs; // milliseconds from the start of the recording

  const RecordedHit({
    required this.noteIndex,
    required this.octave,
    required this.atMs,
  });

  Map<String, dynamic> toJson() => {
        'n': noteIndex,
        'o': octave.index,
        't': atMs,
      };

  factory RecordedHit.fromJson(Map<String, dynamic> j) => RecordedHit(
        noteIndex: j['n'] as int,
        octave: Octave.values[j['o'] as int],
        atMs: j['t'] as int,
      );
}

/// A captured tune: an ordered list of hits.
class Recording {
  final List<RecordedHit> hits;

  const Recording(this.hits);

  bool get isEmpty => hits.isEmpty;

  int get durationMs => hits.isEmpty ? 0 : hits.last.atMs;

  String encode() => jsonEncode(hits.map((h) => h.toJson()).toList());

  static Recording? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List;
      final hits = list
          .map((e) => RecordedHit.fromJson(e as Map<String, dynamic>))
          .toList();
      return hits.isEmpty ? null : Recording(hits);
    } catch (_) {
      return null;
    }
  }
}
