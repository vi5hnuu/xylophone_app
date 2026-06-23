import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';
import '../models/recording.dart';

/// Persists the few things worth remembering between sessions: the active
/// octave, the volume, and the last recorded tune.
class SettingsStore {
  static const _kOctave = 'octave';
  static const _kVolume = 'volume';
  static const _kRecording = 'recording';

  final SharedPreferences _prefs;
  SettingsStore(this._prefs);

  static Future<SettingsStore> create() async =>
      SettingsStore(await SharedPreferences.getInstance());

  Octave get octave =>
      Octave.values[(_prefs.getInt(_kOctave) ?? Octave.mid.index)
          .clamp(0, Octave.values.length - 1)];
  set octave(Octave o) => _prefs.setInt(_kOctave, o.index);

  double get volume => _prefs.getDouble(_kVolume) ?? 0.85;
  set volume(double v) => _prefs.setDouble(_kVolume, v);

  Recording? get recording => Recording.decode(_prefs.getString(_kRecording));
  set recording(Recording? r) {
    if (r == null || r.isEmpty) {
      _prefs.remove(_kRecording);
    } else {
      _prefs.setString(_kRecording, r.encode());
    }
  }
}
