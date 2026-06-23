import 'package:flutter/material.dart';

/// One xylophone key. Visual tokens (gradient, letter colour, bar height) come
/// straight from the redesign source. Index 0..6 = C D E F G A B.
class Note {
  final String label; // C, D, E, F, G, A, B
  final Color top; // gradient top
  final Color bottom; // gradient bottom (also the key's base colour / dot)
  final Color letter; // colour of the note letter
  final double heightFactor; // fraction of panel height (graduated bars)

  const Note({
    required this.label,
    required this.top,
    required this.bottom,
    required this.letter,
    required this.heightFactor,
  });

  List<Color> get gradient => [top, bottom];
}

/// The seven keys, left → right, with graduated heights (a real xylophone).
const List<Note> kNotes = [
  Note(label: 'C', top: Color(0xFFFFB3BF), bottom: Color(0xFFFF93A4), letter: Color(0xFFE5677C), heightFactor: 0.97),
  Note(label: 'D', top: Color(0xFFFFD0AD), bottom: Color(0xFFFFB98A), letter: Color(0xFFD98A45), heightFactor: 0.91),
  Note(label: 'E', top: Color(0xFFFFEBA8), bottom: Color(0xFFFFDD7C), letter: Color(0xFFD2A52E), heightFactor: 0.85),
  Note(label: 'F', top: Color(0xFFC8EDAC), bottom: Color(0xFFA9E085), letter: Color(0xFF5E9C3C), heightFactor: 0.79),
  Note(label: 'G', top: Color(0xFFA8E8DE), bottom: Color(0xFF7FD8CB), letter: Color(0xFF34998A), heightFactor: 0.73),
  Note(label: 'A', top: Color(0xFFB8CFFF), bottom: Color(0xFF92B4FF), letter: Color(0xFF4F76D6), heightFactor: 0.67),
  Note(label: 'B', top: Color(0xFFD7C2F4), bottom: Color(0xFFBFA0EC), letter: Color(0xFF8157C9), heightFactor: 0.61),
];

/// The three playable octaves. The same tones are pitched up/down by playback
/// rate, so we never need extra samples.
enum Octave { low, mid, high }

extension OctaveX on Octave {
  String get label => switch (this) {
        Octave.low => 'Low',
        Octave.mid => 'Mid',
        Octave.high => 'High',
      };

  /// Playback-rate multiplier. One octave = ×2 in frequency.
  double get rate => switch (this) {
        Octave.low => 0.5,
        Octave.mid => 1.0,
        Octave.high => 2.0,
      };

  Octave? get lower => this == Octave.low
      ? null
      : (this == Octave.high ? Octave.mid : Octave.low);

  Octave? get higher => this == Octave.high
      ? null
      : (this == Octave.low ? Octave.mid : Octave.high);
}
