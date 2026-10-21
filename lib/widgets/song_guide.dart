import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/note.dart';
import '../state/xylophone_controller.dart';

/// Strip shown while learning a song: title, progress, the next few notes as
/// coloured letter chips, a "Listen" demo button and a close button.
class SongGuide extends StatelessWidget {
  const SongGuide({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<XylophoneController>();
    final song = c.activeSong;
    if (song == null) return const SizedBox.shrink();
    final step = c.songStep;
    final upcoming = song.notes.skip(step).take(8).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.pillShadow(),
      ),
      child: Row(
        children: [
          Text(song.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.ink)),
                    ),
                    Text('$step/${song.notes.length}',
                        style: AppTheme.nunitoLabel(
                            size: 11,
                            weight: FontWeight.w700,
                            color: AppTheme.hint,
                            spacing: 0)),
                  ],
                ),
                const SizedBox(height: 6),
                // Non-interactive scroll so extra chips clip at the edge
                // instead of overflowing.
                SizedBox(
                  height: 24,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(
                      children: [
                        for (int i = 0; i < upcoming.length; i++) ...[
                          _NoteChip(
                            note: kNotes[upcoming[i].noteIndex],
                            next: i == 0,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Listen',
            onPressed: c.isPlaying ? c.stopPlayback : c.playSongDemo,
            icon: Icon(
              c.isPlaying ? Icons.stop_rounded : Icons.headphones_rounded,
              color: AppTheme.playBtnFg,
            ),
          ),
          IconButton(
            tooltip: 'Close song',
            onPressed: c.exitSong,
            icon: const Icon(Icons.close_rounded, color: AppTheme.clearIcon),
          ),
        ],
      ),
    );
  }
}

class _NoteChip extends StatelessWidget {
  final Note note;
  final bool next;
  const _NoteChip({required this.note, required this.next});

  @override
  Widget build(BuildContext context) {
    final size = next ? 24.0 : 18.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: next ? note.bottom : note.top,
        shape: BoxShape.circle,
        border: next ? Border.all(color: Colors.white, width: 2) : null,
        boxShadow: next
            ? [BoxShadow(color: note.bottom.withValues(alpha: 0.5), blurRadius: 6)]
            : null,
      ),
      child: Text(note.label,
          style: TextStyle(
              fontSize: next ? 12 : 9.5,
              fontWeight: FontWeight.w700,
              color: next ? Colors.white : note.letter,
              height: 1.0)),
    );
  }
}
