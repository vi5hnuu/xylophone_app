import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../services/ad_manager.dart';
import '../services/purchase_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/instrument_header.dart';
import '../widgets/octave_control.dart';
import '../widgets/record_bar.dart';
import '../widgets/xylophone_keys.dart';
import 'settings_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<PurchaseService>().isPro;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.background),
        child: Stack(
          children: [
            const _Blobs(),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
                    child: InstrumentHeader(
                      onSettings: () async {
                        await showSettingsSheet(context);
                        // A natural break — maybe show an interstitial (free,
                        // cooldown-limited).
                        if (context.mounted) {
                          context.read<AdManager>().maybeShowInterstitial();
                        }
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(22, 8, 22, 6),
                    child: OctaveControl(),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(18, 14, 18, 6),
                      child: XylophoneKeys(),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(22, 6, 22, isPro ? 16 : 8),
                    child: const RecordBar(),
                  ),
                  // Free users: a compact banner that reserves its own space,
                  // pushing the instrument up rather than covering it.
                  if (!isPro)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: BannerAdWidget(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Decorative blurred colour blobs behind everything (matching the source).
class _Blobs extends StatelessWidget {
  const _Blobs();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -50,
            child: _Blob(color: Color(0xFFFFE0E6), size: 200),
          ),
          Positioned(
            bottom: 120,
            left: -70,
            child: _Blob(color: Color(0xFFE2E6FF), size: 220),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
