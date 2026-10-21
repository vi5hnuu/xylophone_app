import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';
import '../services/ad_free_pass.dart';
import '../services/ad_manager.dart';
import '../services/purchase_service.dart';
import '../widgets/parental_gate.dart';
import 'pro_sheet.dart';

const String _privacyUrl =
    'https://legal.laxmi.solutions/xylophone/privacy-policy';
const String _termsUrl =
    'https://legal.laxmi.solutions/xylophone/terms-of-service';
const String _storeUrl =
    'https://play.google.com/store/apps/details?id=com.vi5hnu.xylophone';
const String _supportEmail = 'laxmi.solutions.2025@gmail.com';

Future<void> showSettingsSheet(BuildContext context) {
  context.read<PurchaseService>().clearNotice();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const SettingsSheet(),
  );
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final purchases = context.watch<PurchaseService>();
    final isPro = purchases.isPro;
    final pass = context.watch<AdFreePass>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppTheme.sliderTrack,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (!isPro) _ProBanner(),
            if (isPro)
              const _Tile(
                icon: Icons.workspace_premium_rounded,
                label: 'Xylophone Pro',
                trailing: Text('Active',
                    style: TextStyle(
                        color: Color(0xFF4F9B3E),
                        fontWeight: FontWeight.w700)),
              ),
            if (!isPro && pass.active)
              _Tile(
                icon: Icons.timer_outlined,
                label: 'Ad-free time left',
                trailing: Text(formatRemaining(pass.remaining),
                    style: const TextStyle(
                        color: Color(0xFF4F9B3E),
                        fontWeight: FontWeight.w700)),
              ),
            if (!isPro)
              _Tile(
                icon: Icons.restore_rounded,
                label: 'Restore purchase',
                trailing: purchases.restoring
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        switch (purchases.notice) {
                          PurchaseNotice.nothingToRestore => 'None found',
                          PurchaseNotice.pending => 'Payment pending',
                          PurchaseNotice.storeUnavailable => 'Offline',
                          _ => '',
                        },
                        style: const TextStyle(color: AppTheme.inkSoft)),
                onTap: purchases.restore,
              ),
            const _SectionLabel('Help'),
            _Tile(
              icon: Icons.star_outline_rounded,
              label: 'Rate Xylophone',
              onTap: () => _openGated(context, Uri.parse(_storeUrl)),
            ),
            _Tile(
              icon: Icons.mail_outline_rounded,
              label: 'Contact support',
              onTap: () => _openGated(
                context,
                Uri(
                  scheme: 'mailto',
                  path: _supportEmail,
                  query: 'subject=Xylophone%20support',
                ),
              ),
            ),
            const _SectionLabel('Legal'),
            _Tile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () => _openGated(context, Uri.parse(_privacyUrl)),
            ),
            _Tile(
              icon: Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () => _openGated(context, Uri.parse(_termsUrl)),
            ),
            const _SectionLabel('About'),
            _Tile(
              icon: Icons.info_outline_rounded,
              label: 'Version',
              trailing: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) => Text(
                  snap.data?.version ?? '',
                  style: const TextStyle(color: AppTheme.inkSoft),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Made with ♥ by Laxmi Solutions',
                  style: TextStyle(color: AppTheme.inkSoft, fontSize: 12)),
            ),
          ],
          ),
        ),
      ),
    );
  }

  /// Anything that leaves the app sits behind the grown-ups check, and
  /// returning from it must not trigger an app-open ad.
  Future<void> _openGated(BuildContext context, Uri uri) async {
    final ads = context.read<AdManager>();
    if (!await showParentalGate(context)) return;
    ads.suppressAppOpenOnce();
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ProBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final purchases = context.watch<PurchaseService>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showProSheet(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.glyphGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 30),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Go Pro: all songs, no ads',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5)),
                    Text('A one-time purchase · no subscription',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  purchases.priceLabel ?? 'Pro',
                  style: const TextStyle(
                      color: AppTheme.accent, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 4),
      child: Text(text.toUpperCase(), style: AppTheme.overline()),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 21, color: AppTheme.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, color: AppTheme.ink)),
            ),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null)
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.inkSoft),
          ],
        ),
      ),
    );
  }
}
