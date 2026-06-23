import 'dart:math';
import 'dart:typed_data';

/// Synthesises the xylophone mallet tone in pure Dart, mirroring the Web-Audio
/// recipe in the design source: a sine fundamental plus a bright inharmonic
/// partial at ~4× with fast exponential decays. Output is a 16-bit PCM mono WAV.
///
/// Each note is synthesised at its true pitch (a C-major scale), so notes are
/// always in tune; octaves shift the frequency (`freq * 2^(octave-2)`).
class ToneSynth {
  static const int sampleRate = 44100;
  static const double _noteDuration = 1.8; // seconds per note

  /// C-major scale: C4 D4 E4 F4 G4 A4 B4 (Hz) — identical to the design.
  static const List<double> baseFreqs = [
    261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88,
  ];

  /// Raw mono samples (−1..1) for a single mallet strike at [freq].
  static Float64List samplesForFreq(double freq) {
    final int n = (_noteDuration * sampleRate).round();
    final samples = Float64List(n);

    const double a1 = 0.70; // fundamental peak
    const double a2 = 0.21; // partial peak (≈ a1 * 0.3)
    const double floor = 0.0001;
    final double partialFreq = freq * 4.01;

    for (int i = 0; i < n; i++) {
      final double t = i / sampleRate;

      final double env1 =
          _expEnv(t, peak: a1, attack: 0.004, decay: 1.7, floor: floor);
      final double s1 = sin(2 * pi * freq * t) * env1;

      double s2 = 0;
      if (t < 0.5) {
        final double env2 =
            _expEnv(t, peak: a2, attack: 0.004, decay: 0.4, floor: floor);
        s2 = sin(2 * pi * partialFreq * t) * env2;
      }

      samples[i] = (s1 + s2).clamp(-1.0, 1.0);
    }
    return samples;
  }

  /// Build a single-note WAV for [freq] (used to feed the playback engine).
  static Uint8List wavForFreq(double freq) =>
      _encodeWavMono16(samplesForFreq(freq));

  /// Render a recorded tune — a list of (frequency, start-time) hits — into one
  /// mixed WAV, so it can be saved as an audio file. Overlapping notes are summed
  /// and the whole mix is normalised to avoid clipping.
  static Uint8List renderTuneWav(List<({double freq, int atMs})> notes) {
    if (notes.isEmpty) return _encodeWavMono16(Float64List(0));

    final int tail = (_noteDuration * sampleRate).round();
    int lastStart = 0;
    for (final note in notes) {
      final s = (note.atMs / 1000 * sampleRate).round();
      if (s > lastStart) lastStart = s;
    }
    final mix = Float64List(lastStart + tail);

    for (final note in notes) {
      final int start = (note.atMs / 1000 * sampleRate).round();
      final tone = samplesForFreq(note.freq);
      for (int i = 0; i < tone.length; i++) {
        mix[start + i] += tone[i];
      }
    }

    // Normalise if summing pushed the peak above 1.0.
    double peak = 0;
    for (final v in mix) {
      final a = v.abs();
      if (a > peak) peak = a;
    }
    if (peak > 1.0) {
      final scale = 0.97 / peak;
      for (int i = 0; i < mix.length; i++) {
        mix[i] *= scale;
      }
    }
    return _encodeWavMono16(mix);
  }

  /// Attack from `floor`→`peak`, then exponential decay `peak`→`floor`.
  static double _expEnv(double t,
      {required double peak,
      required double attack,
      required double decay,
      required double floor}) {
    if (t < attack) {
      return floor * pow(peak / floor, t / attack);
    }
    final double td = t - attack;
    if (td >= decay) return 0;
    return peak * pow(floor / peak, td / decay);
  }

  static Uint8List _encodeWavMono16(Float64List samples) {
    final int dataLen = samples.length * 2;
    final bytes = BytesBuilder();
    final header = ByteData(44);

    void writeStr(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    header.setUint32(4, 36 + dataLen, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // fmt chunk size
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    header.setUint16(32, 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little); // bits per sample
    writeStr(36, 'data');
    header.setUint32(40, dataLen, Endian.little);
    bytes.add(header.buffer.asUint8List());

    final pcm = ByteData(dataLen);
    for (int i = 0; i < samples.length; i++) {
      pcm.setInt16(i * 2, (samples[i] * 32767).round().clamp(-32768, 32767),
          Endian.little);
    }
    bytes.add(pcm.buffer.asUint8List());
    return bytes.toBytes();
  }
}
