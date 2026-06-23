import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/note.dart';
import '../state/xylophone_controller.dart';

/// Controls row: the octave stepper pill and the volume slider pill.
class OctaveControl extends StatelessWidget {
  const OctaveControl({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<XylophoneController>();
    return Row(
      children: [
        _Pill(
          padding: const EdgeInsets.all(5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepBtn(
                  glyph: '−',
                  onTap: c.octave.lower == null ? null : () => c.nudgeOctave(-1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 11),
                child: SizedBox(
                  width: 58,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('OCTAVE',
                          style: AppTheme.nunitoLabel(
                              size: 9,
                              weight: FontWeight.w700,
                              color: AppTheme.octaveLabelTop,
                              spacing: 1.0)),
                      const SizedBox(height: 2),
                      Text(c.octave.label,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.octaveLabel,
                              height: 1.0)),
                    ],
                  ),
                ),
              ),
              _StepBtn(
                  glyph: '+',
                  onTap: c.octave.higher == null ? null : () => c.nudgeOctave(1)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Pill(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: Row(
              children: [
                const Text('🔊', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 8,
                        activeTrackColor: AppTheme.sliderThumbBorder,
                        inactiveTrackColor: AppTheme.sliderTrack,
                        thumbColor: Colors.white,
                        overlayColor:
                            AppTheme.sliderThumbBorder.withValues(alpha: 0.12),
                        thumbShape: const _RingThumb(),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
                        trackShape: const RoundedRectSliderTrackShape(),
                      ),
                      child: Slider(value: c.volume, onChanged: c.setVolume),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Pill({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    // No forced height / stretch — each pill sizes to its (padded) content. The
    // paddings below are tuned so both pills end up the same ~40px height while
    // the −/+ buttons keep their breathing room.
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.pillShadow(),
      ),
      child: child,
    );
  }
}

class _StepBtn extends StatelessWidget {
  final String glyph;
  final VoidCallback? onTap;
  const _StepBtn({required this.glyph, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: AppTheme.pillTint,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: Text(
              glyph,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.0,
                color: enabled
                    ? AppTheme.pillIcon
                    : AppTheme.pillIcon.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White slider thumb with a coloured ring (3px border), per the design.
class _RingThumb extends SliderComponentShape {
  const _RingThumb();

  @override
  Size getPreferredSize(bool enabled, bool isDiscrete) => const Size(20, 20);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    final shadow = Paint()
      ..color = const Color(0x40502878)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center + const Offset(0, 2), 10, shadow);
    canvas.drawCircle(center, 10, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      8.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppTheme.sliderThumbBorder,
    );
  }
}
