import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/theme.dart';
import 'screens/home_screen.dart';
import 'services/ad_manager.dart';
import 'services/ads_service.dart';
import 'services/audio_service.dart';
import 'services/purchase_service.dart';
import 'services/settings_store.dart';
import 'state/xylophone_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );

  // Only the (fast) settings load blocks first paint. The controller pushes the
  // saved octave & volume onto the audio service.
  final store = await SettingsStore.create();
  final audio = AudioService();
  final controller = XylophoneController(audio, store);
  final purchases = PurchaseService();
  final adManager = AdManager(purchases);

  // Show the UI immediately, then warm up the heavier services in the
  // background (synthesising tones, AdMob, billing). The instrument renders at
  // once; audio simply no-ops until it's ready, and ads/Pro update when ready.
  // Each is guarded so a failure can never blank the screen.
  runApp(XylophoneApp(
    controller: controller,
    purchases: purchases,
    adManager: adManager,
  ));

  _warmUp('audio', audio.init);
  _warmUp('ads', () async {
    await AdsService.init();
    adManager.start();
  });
  _warmUp('purchases', purchases.init);
}

void _warmUp(String name, Future<void> Function() init) {
  init().catchError((Object e, StackTrace s) {
    debugPrint('Xylophone: $name init failed: $e');
  });
}

class XylophoneApp extends StatelessWidget {
  final XylophoneController controller;
  final PurchaseService purchases;
  final AdManager adManager;

  const XylophoneApp({
    super.key,
    required this.controller,
    required this.purchases,
    required this.adManager,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: controller),
        ChangeNotifierProvider.value(value: purchases),
        Provider<AdManager>.value(value: adManager),
      ],
      child: MaterialApp(
        title: 'Xylophone',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeData(),
        home: const HomeScreen(),
      ),
    );
  }
}
