import 'dart:math';

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// "Ask a grown-up" check shown before purchases and before anything that
/// leaves the app (store, browser, email). The answer to a multiplication must
/// be typed on a keypad (a 1-in-90 guess), and a wrong answer closes the gate,
/// so a child tapping at random can't get through. Resolves to true only when
/// the right answer is entered.
Future<bool> showParentalGate(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => const _ParentalGate(),
  );
  return ok ?? false;
}

class _ParentalGate extends StatefulWidget {
  const _ParentalGate();

  @override
  State<_ParentalGate> createState() => _ParentalGateState();
}

class _ParentalGateState extends State<_ParentalGate> {
  late final int _a;
  late final int _b;
  String _entry = '';

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _a = 3 + rng.nextInt(7); // 3..9 → a two-digit answer most of the time
    _b = 4 + rng.nextInt(6);
  }

  void _digit(int d) {
    if (_entry.length >= 2) return;
    setState(() => _entry += '$d');
  }

  void _backspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  void _submit() {
    if (_entry.isEmpty) return;
    Navigator.of(context).pop(int.parse(_entry) == _a * _b);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Grown-ups only',
          style: AppTheme.title().copyWith(fontSize: 20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('To continue, please type the answer:',
              style: TextStyle(color: AppTheme.inkSoft, fontSize: 13.5)),
          const SizedBox(height: 10),
          Text('$_a × $_b = ${_entry.isEmpty ? '?' : _entry}',
              style: AppTheme.title().copyWith(fontSize: 28)),
          const SizedBox(height: 14),
          // Plain rows, not a GridView: AlertDialog measures intrinsic width,
          // which scrollables don't support.
          for (final row in const [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9],
          ])
            _KeyRow(children: [
              for (final d in row) _Key(label: '$d', onTap: () => _digit(d)),
            ]),
          _KeyRow(children: [
            _Key(icon: Icons.backspace_outlined, onTap: _backspace),
            _Key(label: '0', onTap: () => _digit(0)),
            _Key(
              icon: Icons.check_rounded,
              onTap: _entry.isEmpty ? null : _submit,
              filled: true,
            ),
          ]),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _KeyRow extends StatelessWidget {
  final List<Widget> children;
  const _KeyRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            SizedBox(width: 64, height: 44, child: children[i]),
          ],
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  const _Key({this.label, this.icon, this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : AppTheme.accent;
    return Material(
      color: filled
          ? AppTheme.accent.withValues(alpha: onTap == null ? 0.4 : 1)
          : AppTheme.pillTint,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Center(
          child: icon != null
              ? Icon(icon, color: fg, size: 22)
              : Text(label!,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }
}
