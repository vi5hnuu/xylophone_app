import 'dart:math';
import 'dart:typed_data';

/// Synthesises the xylophone mallet tone in pure Dart, mirroring the Web-Audio
/// recipe in the design source: a sine fundamental plus a bright inharmonic
/// partial at ~4× with fast exponential decays. Output is a 16-bit PCM mono WAV
/// so it can be fed straight to audioplayers as a [BytesSource].
///
/// We synthesise each note at its true pitch (a C-major scale), so the notes are
/// always in tune; octaves are then handled by playback rate (×0.5 / ×1 / ×2),
/// exactly like `freq * 2^(octave-2)` in the design.
class ToneSynth {
  static const int sampleRate = 44100;

  /// C-major scale: C4 D4 E4 F4 G4 A4 B4 (Hz) — identical to the design.
  static const List<double> baseFreqs = [
    261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88,
  ];

  /// Build a WAV for [freq]. Peak amplitude is kept below 1.0 so the runtime
  /// volume can be controlled by the player (not baked into the sample).
  static Uint8List wavForFreq(double freq) {
    const double duration = 1.8; // seconds
    final int n = (duration * sampleRate).round();
    final samples = Float64List(n);

    const double a1 = 0.70; // fundamental peak
    const double a2 = 0.21; // partial peak (≈ a1 * 0.3)
    const double floor = 0.0001;
    final double partialFreq = freq * 4.01;

    for (int i = 0; i < n; i++) {
      final double t = i / sampleRate;

      final double env1 = _expEnv(t, peak: a1, attack: 0.004, decay: 1.7, floor: floor);
      final double s1 = sin(2 * pi * freq * t) * env1;

      double s2 = 0;
      if (t < 0.5) {
        final double env2 =
            _expEnv(t, peak: a2, attack: 0.004, decay: 0.4, floor: floor);
        s2 = sin(2 * pi * partialFreq * t) * env2;
      }

      samples[i] = (s1 + s2).clamp(-1.0, 1.0);
    }

    return _encodeWavMono16(samples);
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
