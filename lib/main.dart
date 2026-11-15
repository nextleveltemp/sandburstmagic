import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'bootstrap.dart';

/// How long the launch screen (the app icon) stays up at minimum.
/// Loading takes longer on slow phones; on fast ones the icon would only
/// flash by without this.
const _minimumSplash = Duration(milliseconds: 1500);

Future<void> main() async {
  final started = DateTime.now();
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Android keeps showing the launch screen until Flutter draws its first
  // frame, so hold that frame back until loading is done.
  binding.deferFirstFrame();
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Outfit font'], text);
  });
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final services = await bootstrap();
  runApp(SandBurstMagicApp(services: services));
  final elapsed = DateTime.now().difference(started);
  if (elapsed < _minimumSplash) {
    await Future<void>.delayed(_minimumSplash - elapsed);
  }
  binding.allowFirstFrame();
}
