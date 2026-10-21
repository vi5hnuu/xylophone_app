import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/note.dart';
import '../models/song.dart';
import '../services/purchase_service.dart';
import '../state/xylophone_controller.dart';
import 'pro_sheet.dart';

Future<void> showSongsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const SongsSheet(),
  );
}

/// The song book: pick a melody to learn by following the glowing keys. The
/// first songs are free; the rest come with Pro.
class SongsSheet extends StatelessWidget {
  const SongsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isPro = context.select<PurchaseService, bool>((p) => p.isPro);
    final active = context.select<XylophoneController, Song?>(
        (c) => c.activeSong);

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.sliderTrack,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Song Book', style: AppTheme.title().copyWith(fontSize: 21)),
            const SizedBox(height: 4),
            const Text('Pick a song, then tap the key that glows!',
                style: TextStyle(color: AppTheme.inkSoft, fontSize: 13)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final song in kSongs)
                    _SongTile(
                      song: song,
                      locked: !song.free && !isPro,
                      active: song.id == active?.id,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final bool locked;
  final bool active;
  const _SongTile({
    required this.song,
    required this.locked,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: active ? AppTheme.pillTint : AppTheme.stripBg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (locked) {
              showProSheet(context,
                  reason: '“${song.title}” is a Pro song');
              return;
            }
            context.read<XylophoneController>().startSong(song);
            Navigator.of(context).pop();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Text(song.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.ink)),
                      const SizedBox(height: 4),
                      _NoteDots(song: song),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (locked)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: AppTheme.glyphGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 3),
                        Text('PRO',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  )
                else
                  const Icon(Icons.play_circle_fill_rounded,
                      color: AppTheme.sliderThumbBorder, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A peek at the song's first notes as coloured dots (the key colours).
class _NoteDots extends StatelessWidget {
  final Song song;
  const _NoteDots({required this.song});

  @override
  Widget build(BuildContext context) {
    final preview = song.notes.take(12);
    return Row(
      children: [
        for (final n in preview) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: kNotes[n.noteIndex].bottom,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
        ],
      ],
    );
  }
}
