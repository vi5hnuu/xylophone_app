import 'package:flutter_soloud/flutter_soloud.dart';

import '../models/note.dart';
import 'tone_synth.dart';

/// Plays the synthesised xylophone tones with the SoLoud engine (C++/FFI) — very
/// low latency and naturally polyphonic.
///
/// All 21 tones (7 notes × 3 octaves) are synthesised at their true pitch and
/// pre-loaded once, so striking a key is a single fire-and-forget `play()` at
/// native speed: instant, in tune, and overlapping like a real instrument. No
/// playback-rate tricks, no awaits on the hot path.
class AudioService {
  final SoLoud _soloud = SoLoud.instance;

  /// [octaveIndex][noteIndex] → preloaded source.
  final List<List<AudioSource>> _sources = [];
  double _volume = 0.85;
  Octave _octave = Octave.mid;
  bool muted = false;
  bool _ready = false;

  Future<void> init() async {
    if (!_soloud.isInitialized) {
      await _soloud.init();
    }
    for (final octave in Octave.values) {
      final row = <AudioSource>[];
      for (int n = 0; n < ToneSynth.baseFreqs.length; n++) {
        final freq = ToneSynth.baseFreqs[n] * octave.rate;
        final wav = ToneSynth.wavForFreq(freq);
        row.add(await _soloud.loadMem('note_${octave.index}_$n', wav));
      }
      _sources.add(row);
    }
    _ready = true;
  }

  bool get isReady => _ready;

  set volume(double v) => _volume = v.clamp(0.0, 1.0);
  set octave(Octave o) => _octave = o;

  /// Strike a key — immediate, fire-and-forget. [octave] overrides the global
  /// octave for recorded-tune playback (each hit remembers its octave).
  void play(int index, {Octave? octave}) {
    if (!_ready || muted) return;
    final oct = octave ?? _octave;
    if (index < 0 || index >= _sources[oct.index].length) return;
    // Not awaited: schedule the sound and return immediately for low latency.
    _soloud.play(_sources[oct.index][index], volume: _volume);
  }

  Future<void> dispose() async {
    if (_soloud.isInitialized) _soloud.deinit();
    _sources.clear();
    _ready = false;
  }
}
