import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../models/song.dart';
import '../services/ad_manager.dart';
import '../services/purchase_service.dart';
import '../state/xylophone_controller.dart';
import '../widgets/ad_offer_bar.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/instrument_header.dart';
import '../widgets/octave_control.dart';
import '../widgets/record_bar.dart';
import '../widgets/song_guide.dart';
import '../widgets/xylophone_keys.dart';
import 'settings_sheet.dart';
import 'songs_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<Song>? _songDone;

  @override
  void initState() {
    super.initState();
    _songDone = context
        .read<XylophoneController>()
        .songCompleted
        .listen(_celebrate);
  }

  @override
  void dispose() {
    _songDone?.cancel();
    super.dispose();
  }

  /// A finished song: cheer, then — once the child taps on — it's a natural
  /// break where an interstitial may show (free users, cooldown-limited).
  Future<void> _celebrate(Song song) async {
    final next = await showDialog<_AfterSong>(
      context: context,
      builder: (_) => _CelebrationDialog(song: song),
    );
    if (!mounted) return;
    context.read<AdManager>().onNaturalBreak();
    if (next == _AfterSong.pickAnother) {
      context.read<XylophoneController>().exitSong();
      showSongsSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adsOff = context.select<AdManager, bool>((a) => a.adsOff);
    final isPro = context.select<PurchaseService, bool>((p) => p.isPro);
    final inSong = context.select<XylophoneController, bool>(
        (c) => c.activeSong != null);

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
                      onSongs: () => showSongsSheet(context),
                      onSettings: () => showSettingsSheet(context),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(22, 8, 22, 6),
                    child: OctaveControl(),
                  ),
                  if (inSong)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(22, 8, 22, 0),
                      child: SongGuide(),
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
                  // Free users: the ad-free offers (or the ad-free time left),
                  // then a compact banner that reserves its own space, pushing
                  // the instrument up rather than covering it.
                  if (!isPro)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: AdOfferBar(),
                    ),
                  if (!adsOff)
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

enum _AfterSong { again, pickAnother }

class _CelebrationDialog extends StatelessWidget {
  final Song song;
  const _CelebrationDialog({required this.song});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 8),
            Text('Bravo!', style: AppTheme.title().copyWith(fontSize: 26)),
            const SizedBox(height: 6),
            Text('You played “${song.title}”',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.inkSoft, fontSize: 14)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.of(context).pop(_AfterSong.again),
                child: const Text('Play again',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_AfterSong.pickAnother),
              child: const Text('Pick another song'),
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
