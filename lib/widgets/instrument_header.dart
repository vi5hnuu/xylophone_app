import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../state/xylophone_controller.dart';

/// Header: app glyph + title on the left; songs, mute and settings buttons on
/// the right.
class InstrumentHeader extends StatelessWidget {
  final VoidCallback onSongs;
  final VoidCallback onSettings;
  const InstrumentHeader({
    super.key,
    required this.onSongs,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.select<XylophoneController, bool>((c) => c.muted);
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
          decoration: BoxDecoration(
            gradient: AppTheme.glyphGradient,
            borderRadius: BorderRadius.circular(15),
            boxShadow: AppTheme.glyphShadow(),
          ),
          child: const _GlyphBars(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Xylophone', style: AppTheme.title()),
              const SizedBox(height: 4),
              Text('TAP · PLAY · RECORD',
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: AppTheme.nunitoLabel()),
            ],
          ),
        ),
        _HeaderButton(
          icon: Icons.library_music_rounded,
          tooltip: 'Songs',
          onTap: onSongs,
        ),
        const SizedBox(width: 9),
        _HeaderButton(
          tooltip: muted ? 'Unmute' : 'Mute',
          icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          onTap: context.read<XylophoneController>().toggleMute,
        ),
        const SizedBox(width: 9),
        _HeaderButton(
          icon: Icons.settings_rounded,
          tooltip: 'Settings',
          onTap: onSettings,
        ),
      ],
    );
  }
}

/// The little white bar-chart inside the glyph (heights 60/80/48/70%).
class _GlyphBars extends StatelessWidget {
  const _GlyphBars();

  @override
  Widget build(BuildContext context) {
    const heights = [0.60, 0.80, 0.48, 0.70];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < heights.length; i++) ...[
          Expanded(
            child: FractionallySizedBox(
              heightFactor: heights[i],
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          if (i != heights.length - 1) const SizedBox(width: 2.5),
        ],
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // The shadow lives on a box *outside* the Material: Material clips what
    // it paints (including Ink decorations) to its rounded shape, which used to
    // crop the shadow at the button's edges.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.headerBtnShadow(),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, size: 20, color: AppTheme.pillIcon),
            ),
          ),
        ),
      ),
    );
  }
}
