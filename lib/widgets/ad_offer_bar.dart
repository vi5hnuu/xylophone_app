import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../screens/pro_sheet.dart';
import '../services/ad_free_pass.dart';
import '../services/ad_manager.dart';
import '../services/purchase_service.dart';

/// Line above the banner for free users: "▶ 1 hour ad-free" (watch a rewarded
/// video) and "Remove ads ›" (the Pro sheet). While an earned ad-free hour is
/// running it shows the time left instead. Always visible for free users, even
/// when the banner itself failed to load.
class AdOfferBar extends StatelessWidget {
  const AdOfferBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.select<PurchaseService, bool>((p) => p.isPro)) {
      return const SizedBox.shrink();
    }
    final pass = context.watch<AdFreePass>();
    final ready = context.select<AdManager, bool>((a) => a.rewardedReady);

    if (pass.active) {
      return _Chip(
        icon: Icons.check_circle_rounded,
        label: 'Ad-free · ${formatRemaining(pass.remaining)} left',
        color: const Color(0xFF4F9B3E),
        background: const Color(0xFFEAF7E4),
        onTap: () => showProSheet(context),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Chip(
          icon: Icons.play_circle_fill_rounded,
          label: '1 hour ad-free',
          color: ready ? AppTheme.accent : AppTheme.hint,
          background: AppTheme.pillTint,
          onTap: () => ready ? _watch(context) : showProSheet(context),
        ),
        const SizedBox(width: 10),
        _Chip(
          icon: Icons.workspace_premium_rounded,
          label: 'Remove ads',
          color: AppTheme.accent,
          background: AppTheme.pillTint,
          onTap: () => showProSheet(context),
        ),
      ],
    );
  }

  Future<void> _watch(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await context.read<AdManager>().showRewarded();
    final message = switch (outcome) {
      RewardOutcome.earned => 'Thanks! Enjoy an hour with no ads 🎉',
      RewardOutcome.closedEarly =>
        'Watch the whole video to get your ad-free hour.',
      RewardOutcome.offline => 'Connect to the internet to watch a video.',
      RewardOutcome.unavailable =>
        'No video right now — please try again in a bit.',
      RewardOutcome.notNeeded => null,
    };
    if (message == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: AppTheme.nunitoLabel(
                      size: 12, weight: FontWeight.w800, color: color, spacing: 0)),
            ],
          ),
        ),
      ),
    );
  }
}
