import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/note.dart';
import '../services/purchase_service.dart';
import '../screens/pro_sheet.dart';
import '../state/xylophone_controller.dart';

/// Bottom record strip: record toggle, play, a dots preview of the tune, clear.
class RecordBar extends StatelessWidget {
  const RecordBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<XylophoneController>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.recordStripShadow(),
      ),
      child: Row(
        children: [
          _RecordButton(recording: c.isRecording, onTap: c.toggleRecord),
          const SizedBox(width: 12),
          _CircleButton(
            bg: AppTheme.playBtnBg,
            onTap: c.hasRecording && !c.isPlaying ? c.playRecording : null,
            child: const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Icon(Icons.play_arrow_rounded,
                  size: 22, color: AppTheme.playBtnFg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _Strip(indices: c.recordedNoteIndices)),
          if (c.hasRecording && !c.isRecording) _SaveButton(controller: c),
          if (c.hasRecording)
            GestureDetector(
              onTap: c.clearRecording,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 34,
                height: 46,
                child: Icon(Icons.close_rounded,
                    size: 20, color: AppTheme.clearIcon),
              ),
            ),
        ],
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  final List<int> indices;
  const _Strip({required this.indices});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.stripBg,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.centerLeft,
      child: indices.isEmpty
          ? Text('Tap ● to record your tune',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.nunitoLabel(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: AppTheme.hint,
                  spacing: 0))
          // Non-interactive horizontal scroll so a long tune clips cleanly at
          // the edge instead of overflowing. Reversed so the newest notes stay
          // visible at the right as you record.
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  for (final i in indices.reversed) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: kNotes[i].bottom,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Save the tune so it survives restarts — a Pro feature. Free users see a tiny
/// lock and get the upsell on tap; Pro users get a check once saved.
class _SaveButton extends StatelessWidget {
  final XylophoneController controller;
  const _SaveButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isPro = context.select<PurchaseService, bool>((p) => p.isPro);
    final saved = controller.isSaved;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (saved) return;
        if (isPro) {
          controller.saveRecording();
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(const SnackBar(
              content: Text('Tune saved 🎵'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ));
        } else {
          showProSheet(context);
        }
      },
      child: SizedBox(
        width: 38,
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              saved ? Icons.check_circle_rounded : Icons.bookmark_add_rounded,
              size: 22,
              color: saved ? const Color(0xFF6BB85A) : AppTheme.playBtnFg,
            ),
            if (!isPro && !saved)
              const Positioned(
                right: 2,
                top: 6,
                child: Icon(Icons.lock_rounded, size: 11, color: AppTheme.hint),
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final Color bg;
  final Widget child;
  final VoidCallback? onTap;
  const _CircleButton({required this.bg, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 46, height: 46, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Record button: pink dot when idle, rounded square + pulsing ring when active.
class _RecordButton extends StatefulWidget {
  final bool recording;
  final VoidCallback onTap;
  const _RecordButton({required this.recording, required this.onTap});

  @override
  State<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<_RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.recording) _pulse.repeat();
  }

  @override
  void didUpdateWidget(_RecordButton old) {
    super.didUpdateWidget(old);
    if (widget.recording && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.recording && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.recording;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          return Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rec ? AppTheme.recActiveBg : AppTheme.recIdleBg,
              boxShadow: rec
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF6B81)
                            .withValues(alpha: 0.55 * (1 - t)),
                        blurRadius: 0,
                        spreadRadius: 10 * t,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: rec ? 14 : 16,
                height: rec ? 14 : 16,
                decoration: BoxDecoration(
                  color: rec ? Colors.white : const Color(0xFFFF8A9B),
                  borderRadius: BorderRadius.circular(rec ? 3 : 8),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
