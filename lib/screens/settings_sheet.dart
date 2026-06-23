import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';
import '../services/purchase_service.dart';
import 'pro_sheet.dart';

const String _privacyUrl =
    'https://legal.laxmi.solutions/xylophone/privacy-policy';
const String _termsUrl =
    'https://legal.laxmi.solutions/xylophone/terms-of-service';

Future<void> showSettingsSheet(BuildContext context) {
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
    final isPro = context.watch<PurchaseService>().isPro;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
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
            const _SectionLabel('Legal'),
            _Tile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () => _open(_privacyUrl),
            ),
            _Tile(
              icon: Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () => _open(_termsUrl),
            ),
            const _SectionLabel('About'),
            const _Tile(
              icon: Icons.info_outline_rounded,
              label: 'Version',
              trailing: Text('1.0.0',
                  style: TextStyle(color: AppTheme.inkSoft)),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Made with ♥ by Laxmi Solutions',
                  style: TextStyle(color: AppTheme.inkSoft, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
                    Text('Remove ads with Pro',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5)),
                    Text('A one-time purchase',
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
                  purchases.storeAvailable ? purchases.priceLabel : 'Pro',
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
