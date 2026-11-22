import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/audio.dart';
import 'core/haptics.dart';
import 'services/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF05090D),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final state = await AppState.load();
  Haptics.enabled = state.settings.haptics;
  await AudioManager.instance.init();
  await AudioManager.instance.setSfxEnabled(state.settings.sfx);
  await AudioManager.instance.setMusicEnabled(state.settings.music);
  if (state.settings.music) {
    await AudioManager.instance.startMusic();
  }

  runApp(BombMathApp(state: state));
}
