import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/song.dart';
import '../services/ad_free_pass.dart';
import '../services/ad_manager.dart';
import '../services/purchase_service.dart';
import '../widgets/parental_gate.dart';

/// Opens the Pro sheet. [reason] explains what the user just tried to do
/// (e.g. a locked song) and is shown at the top.
Future<void> showProSheet(BuildContext context, {String? reason}) {
  context.read<PurchaseService>().clearNotice();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProSheet(reason: reason),
  );
}

/// Upsell for the one-time "Xylophone Pro" purchase, plus the free option of
/// watching a video for an hour without ads.
class ProSheet extends StatefulWidget {
  final String? reason;
  const ProSheet({super.key, this.reason});

  @override
  State<ProSheet> createState() => _ProSheetState();
}

class _ProSheetState extends State<ProSheet> {
  String? _rewardMessage;
  bool _watching = false;

  @override
  void initState() {
    super.initState();
    // Retry if the app started offline. Notifies only after an await, so it's
    // safe to start from initState.
    context.read<PurchaseService>().refresh();
  }

  Future<void> _buy() async {
    final purchases = context.read<PurchaseService>();
    final ads = context.read<AdManager>();
    if (!await showParentalGate(context)) return;
    ads.suppressAppOpenOnce(); // the Play sheet pauses the app
    await purchases.buyPro();
  }

  Future<void> _watchVideo() async {
    setState(() {
      _watching = true;
      _rewardMessage = null;
    });
    final outcome = await context.read<AdManager>().showRewarded();
    if (!mounted) return;
    setState(() {
      _watching = false;
      _rewardMessage = switch (outcome) {
        RewardOutcome.earned => 'Thanks! Enjoy an hour with no ads 🎉',
        RewardOutcome.closedEarly =>
          'Watch the whole video to get your ad-free hour.',
        RewardOutcome.offline =>
          'Connect to the internet to watch a video.',
        RewardOutcome.unavailable =>
          'No video right now — please try again in a bit.',
        RewardOutcome.notNeeded => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final purchases = context.watch<PurchaseService>();
    final proSongs = kSongs.where((s) => !s.free).length;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
              Text('Xylophone Pro',
                  style: AppTheme.title().copyWith(fontSize: 22)),
              const SizedBox(height: 6),
              Text(
                widget.reason ?? 'One-time purchase · no subscription',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.inkSoft, fontSize: 13),
              ),
              const SizedBox(height: 18),
              _Perk(text: 'Unlock all ${kSongs.length} sing-along songs '
                  '($proSongs more)'),
              const _Perk(text: 'Save tunes & share them as audio files'),
              const _Perk(text: 'No ads, ever — calm play for little ones'),
              const _Perk(text: 'Pay once, keep it forever ♥'),
              const SizedBox(height: 18),
              if (purchases.isPro)
                const _OwnedBadge()
              else
                _BuyButton(purchases: purchases, onBuy: _buy),
              if (purchases.notice != null) ...[
                const SizedBox(height: 10),
                _NoticeText(notice: purchases.notice!),
              ],
              if (!purchases.isPro) ...[
                const SizedBox(height: 14),
                _RewardedOption(
                  watching: _watching,
                  message: _rewardMessage,
                  onWatch: _watchVideo,
                ),
              ],
              const SizedBox(height: 6),
              TextButton(
                onPressed: purchases.restoring ? null : purchases.restore,
                child: Text(
                    purchases.restoring ? 'Checking…' : 'Restore purchase'),
              ),
              const Text(
                'Payments and refunds are handled by Google Play. Pro is linked '
                'to the Google account that bought it — use “Restore purchase” '
                'on a new device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.hint, fontSize: 11),
              ),
            ],
          ),
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
  final VoidCallback onBuy;
  const _BuyButton({required this.purchases, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final price = purchases.priceLabel;
    final String label;
    VoidCallback? action;
    if (purchases.paymentPending) {
      label = 'Payment pending…';
    } else if (!purchases.storeAvailable) {
      label = 'Google Play unavailable — tap to retry';
      action = purchases.refresh;
    } else if (price == null) {
      label = 'Loading price… tap to retry';
      action = purchases.refresh;
    } else {
      label = 'Unlock Pro — $price';
      action = onBuy;
    }
    if (purchases.purchasePending) action = null;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: action,
        child: purchases.purchasePending
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: action == onBuy ? 16.5 : 14,
                    fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

class _NoticeText extends StatelessWidget {
  final PurchaseNotice notice;
  const _NoticeText({required this.notice});

  @override
  Widget build(BuildContext context) {
    final (text, good) = switch (notice) {
      PurchaseNotice.purchased => ('Thank you! Pro is unlocked 🎉', true),
      PurchaseNotice.restored => ('Pro restored — welcome back!', true),
      PurchaseNotice.nothingToRestore =>
        ('No Pro purchase found on this Google account.', false),
      PurchaseNotice.pending => (
          'Payment pending. Pro unlocks automatically once Google Play '
              'confirms it.',
          false
        ),
      PurchaseNotice.failed =>
        ('The purchase didn’t go through. You weren’t charged.', false),
      PurchaseNotice.verifyFailed => (
          'We couldn’t verify this purchase with Google Play. If you were '
              'charged, it will be refunded automatically.',
          false
        ),
      PurchaseNotice.storeUnavailable =>
        ('Couldn’t reach Google Play. Check your connection.', false),
    };
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: good ? const Color(0xFF4F9B3E) : const Color(0xFFD98A45),
      ),
    );
  }
}

class _RewardedOption extends StatelessWidget {
  final bool watching;
  final String? message;
  final VoidCallback onWatch;
  const _RewardedOption({
    required this.watching,
    required this.message,
    required this.onWatch,
  });

  @override
  Widget build(BuildContext context) {
    final ads = context.watch<AdManager>();
    final pass = context.watch<AdFreePass>();
    final canWatch = !watching && ads.rewardedReady && pass.canEarnMore;

    final String label;
    if (watching) {
      label = 'Starting video…';
    } else if (!pass.canEarnMore) {
      label = 'Ad-free time is full';
    } else if (!ads.rewardedReady) {
      label = 'No video available right now';
    } else {
      label = pass.active
          ? 'Watch a video · add 1 more hour'
          : 'Watch a video · 1 hour ad-free';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.stripBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          if (pass.active)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Ad-free for ${formatRemaining(pass.remaining)} more',
                style: const TextStyle(
                    color: Color(0xFF4F9B3E),
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent,
                side: const BorderSide(color: AppTheme.sliderThumbBorder),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: canWatch ? onWatch : null,
              icon: const Icon(Icons.play_circle_rounded, size: 20),
              label: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.inkSoft, fontSize: 12.5)),
          ],
          const SizedBox(height: 4),
          const Text(
            'Ad-free time counts down only while the app is open.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.hint, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// "52 min" / "1 h 20 min".
String formatRemaining(Duration d) {
  final mins = (d.inSeconds / 60).ceil();
  if (mins < 60) return '$mins min';
  final h = mins ~/ 60, m = mins % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

class _OwnedBadge extends StatelessWidget {
  const _OwnedBadge();

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
