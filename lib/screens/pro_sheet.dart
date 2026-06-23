import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../services/purchase_service.dart';

Future<void> showProSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ProSheet(),
  );
}

/// Upsell for the one-time "Xylophone Pro" purchase that removes ads.
class ProSheet extends StatelessWidget {
  const ProSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final purchases = context.watch<PurchaseService>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppTheme.sliderTrack,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppTheme.glyphGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 14),
            Text('Xylophone Pro', style: AppTheme.title().copyWith(fontSize: 22)),
            const SizedBox(height: 6),
            const Text(
              'A one-time purchase. No subscription.',
              style: TextStyle(color: AppTheme.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 20),
            const _Perk(text: 'Remove all ads'),
            const _Perk(text: 'Save your tunes so they’re kept for next time'),
            const _Perk(text: 'Clean, distraction-free play for little ones'),
            const _Perk(text: 'Support a tiny indie app ♥'),
            const SizedBox(height: 22),
            if (purchases.isPro)
              _OwnedBadge()
            else
              _BuyButton(purchases: purchases),
            const SizedBox(height: 10),
            TextButton(
              onPressed: purchases.storeAvailable ? purchases.restore : null,
              child: const Text('Restore purchase'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  final String text;
  const _Perk({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF7E4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 15, color: Color(0xFF6BB85A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 14.5, color: AppTheme.ink)),
          ),
        ],
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  final PurchaseService purchases;
  const _BuyButton({required this.purchases});

  @override
  Widget build(BuildContext context) {
    final enabled = purchases.storeAvailable &&
        purchases.product != null &&
        !purchases.purchasePending;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: enabled ? purchases.buyPro : null,
        child: purchases.purchasePending
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : Text(
                purchases.storeAvailable
                    ? 'Go Pro — ${purchases.priceLabel}'
                    : 'Store unavailable',
                style: const TextStyle(
                    fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

class _OwnedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7E4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        '✓ You’re Pro — thank you!',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF4F9B3E)),
      ),
    );
  }
}
