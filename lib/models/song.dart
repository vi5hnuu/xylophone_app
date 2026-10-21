/// One step of a song: which key, and how long it lasts (in beats) when the
/// song is demonstrated.
class SongNote {
  final int noteIndex; // 0..6 = C D E F G A B
  final double beats;
  const SongNote(this.noteIndex, this.beats);
}

/// A simple melody a child can learn by following the glowing keys. Every song
/// fits the seven keys of one octave (C–B).
class Song {
  final String id;
  final String title;
  final String emoji;
  final bool free;
  final List<SongNote> notes;

  Song({
    required this.id,
    required this.title,
    required this.emoji,
    required this.free,
    required String score,
  }) : notes = _parse(score);

  /// Parses a compact score like `"E D C2 | E D C2"`: a note letter with an
  /// optional beat count (default 1); `|` bar lines are ignored.
  static List<SongNote> _parse(String score) {
    const letters = 'CDEFGAB';
    return [
      for (final token in score.split(RegExp(r'\s+')))
        if (token.isNotEmpty && token != '|')
          SongNote(
            letters.indexOf(token[0]),
            token.length > 1 ? double.parse(token.substring(1)) : 1,
          ),
    ];
  }
}

final List<Song> kSongs = [
  Song(
    id: 'hot_cross_buns',
    title: 'Hot Cross Buns',
    emoji: '🥯',
    free: true,
    score: 'E D C2 | E D C2 | C.5 C.5 C.5 C.5 D.5 D.5 D.5 D.5 | E D C2',
  ),
  Song(
    id: 'twinkle',
    title: 'Twinkle Twinkle Little Star',
    emoji: '⭐',
    free: true,
    score: 'C C G G | A A G2 | F F E E | D D C2 | '
        'G G F F | E E D2 | G G F F | E E D2 | '
        'C C G G | A A G2 | F F E E | D D C2',
  ),
  Song(
    id: 'this_old_man',
    title: 'This Old Man',
    emoji: '👴',
    free: true,
    score: 'G E G2 | G E G2 | A G F E | D E F2 | '
        'E F G C | C C C C.5 D.5 | E F G2 | G D D F | E D C2',
  ),
  Song(
    id: 'mary',
    title: 'Mary Had a Little Lamb',
    emoji: '🐑',
    free: false,
    score: 'E D C D | E E E2 | D D D2 | E G G2 | '
        'E D C D | E E E E | D D E D | C4',
  ),
  Song(
    id: 'old_macdonald',
    title: 'Old MacDonald',
    emoji: '🐄',
    free: false,
    score: 'G G G D | E E D2 | B B A A | G3 D | '
        'G G G D | E E D2 | B B A A | G4',
  ),
  Song(
    id: 'london_bridge',
    title: 'London Bridge',
    emoji: '🌉',
    free: false,
    score: 'G1.5 A.5 G F | E F G2 | D E F2 | E F G2 | '
        'G1.5 A.5 G F | E F G2 | D2 G2 | E C2',
  ),
  Song(
    id: 'jingle_bells',
    title: 'Jingle Bells',
    emoji: '🔔',
    free: false,
    score: 'E E E2 | E E E2 | E G C1.5 D.5 | E4 | '
        'F F F1.5 F.5 | F E E E.5 E.5 | E D D E | D2 G2',
  ),
  Song(
    id: 'ode_to_joy',
    title: 'Ode to Joy',
    emoji: '🎻',
    free: false,
    score: 'E E F G | G F E D | C C D E | E1.5 D.5 D2 | '
        'E E F G | G F E D | C C D E | D1.5 C.5 C2',
  ),
  Song(
    id: 'au_clair',
    title: 'Au Clair de la Lune',
    emoji: '🌙',
    free: false,
    score: 'C C C D | E2 D2 | C E D D | C4 | '
        'C C C D | E2 D2 | C E D D | C4',
  ),
  Song(
    id: 'lightly_row',
    title: 'Lightly Row',
    emoji: '🚣',
    free: false,
    score: 'G E E2 | F D D2 | C D E F | G G G2 | '
        'G E E2 | F D D2 | C E G G | C4',
  ),
  Song(
    id: 'kumbaya',
    title: 'Kumbaya',
    emoji: '🔥',
    free: false,
    score: 'C E G G2 | G A A G2 | C E G G2 | G F E D2 | '
        'C E G G2 | G A A G2 | F E D D | C4',
  ),
  Song(
    id: 'camptown',
    title: 'Camptown Races',
    emoji: '🐎',
    free: false,
    score: 'G G E G | A G E2 | E D2 | E D2 | '
        'G G E G | A G E2 | D E D C2',
  ),
  Song(
    id: 'saints',
    title: 'When the Saints Go Marching In',
    emoji: '🎺',
    free: false,
    score: 'C E F G4 | C E F G4 | C E F G2 E2 | C2 E2 D4 | '
        'E E D C3 | C E G G F3 | E F G2 E2 | C2 D2 C4',
  ),
];
