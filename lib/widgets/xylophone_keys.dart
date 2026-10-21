import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/note.dart';
import '../state/xylophone_controller.dart';

/// The white panel holding the seven graduated, tappable bars.
class XylophoneKeys extends StatelessWidget {
  const XylophoneKeys({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.read<XylophoneController>();
    // In song mode, the key to play next glows and bobs.
    final expected =
        context.select<XylophoneController, int?>((c) => c.expectedKey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        gradient: AppTheme.panelGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppTheme.panelShadow(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int i = 0; i < kNotes.length; i++) ...[
            Expanded(
              child: _Key(
                note: kNotes[i],
                index: i,
                onStrike: () => c.strike(i),
                struck: c.struck,
                hinted: expected == i,
              ),
            ),
            if (i != kNotes.length - 1) const SizedBox(width: 9),
          ],
        ],
      ),
    );
  }
}

class _Key extends StatefulWidget {
  final Note note;
  final int index;
  final VoidCallback onStrike;
  final ValueNotifier<({int index, int token})?> struck;
  final bool hinted;

  const _Key({
    required this.note,
    required this.index,
    required this.onStrike,
    required this.struck,
    required this.hinted,
  });

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 70),
    reverseDuration: const Duration(milliseconds: 160),
  );
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final AnimationController _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    widget.struck.addListener(_onStruck);
    if (widget.hinted) _hint.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Key old) {
    super.didUpdateWidget(old);
    if (widget.hinted && !_hint.isAnimating) {
      _hint.repeat(reverse: true);
    } else if (!widget.hinted && _hint.isAnimating) {
      _hint
        ..stop()
        ..value = 0;
    }
  }

  void _onStruck() {
    final v = widget.struck.value;
    if (v == null || v.index != widget.index) return;
    _glow.forward(from: 0);
  }

  void _down() {
    widget.onStrike();
    _press.forward();
    _glow.forward(from: 0);
  }

  void _up() => _press.reverse();

  @override
  void dispose() {
    widget.struck.removeListener(_onStruck);
    _press.dispose();
    _glow.dispose();
    _hint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: widget.note.heightFactor,
      widthFactor: 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: _up,
        child: AnimatedBuilder(
          animation: Listenable.merge([_press, _hint]),
          builder: (context, child) {
            final h = widget.hinted ? _hint.value : 0.0;
            return Transform.translate(
              offset: Offset(0, 5 * _press.value - 6 * h),
              child: widget.hinted
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: widget.note.bottom
                                .withValues(alpha: 0.35 + 0.45 * h),
                            blurRadius: 10 + 12 * h,
                            spreadRadius: 1 + 3 * h,
                          ),
                        ],
                      ),
                      child: DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color:
                                Colors.white.withValues(alpha: 0.6 + 0.4 * h),
                            width: 3,
                          ),
                        ),
                        child: child,
                      ),
                    )
                  : child,
            );
          },
          child: _bar(),
        ),
      ),
    );
  }

  Widget _bar() {
    final note = widget.note;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: note.gradient,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: note.bottom.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top highlight (inset 0 3px 0 rgba(255,255,255,.55)).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
            ),
          ),
          // Bottom inner shading for depth.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(18)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Decorative dots near the ends…
          Align(
            alignment: Alignment.topCenter,
            child: Padding(padding: const EdgeInsets.only(top: 13), child: _dot()),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child:
                Padding(padding: const EdgeInsets.only(bottom: 13), child: _dot()),
          ),
          // …and the note disc dead-centre of each bar.
          Align(alignment: Alignment.center, child: _label()),
          // Strike glow.
          AnimatedBuilder(
            animation: _glow,
            builder: (context, _) {
              if (_glow.value == 0 || _glow.isCompleted) {
                return const SizedBox.shrink();
              }
              final t = _glow.value;
              return Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (0.95 * (1 - t)).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.55 + 1.15 * t,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.95),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.68],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dot() => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
      );

  Widget _label() => Container(
        width: 27,
        height: 27,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        child: Text(
          widget.note.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: widget.note.letter,
            height: 1.0,
          ),
        ),
      );
}
