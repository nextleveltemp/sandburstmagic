import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sand_burst_magic/app_info.dart';
import 'package:sand_burst_magic/services/audio_service.dart';

void main() {
  test('AppInfo matches pubspec.yaml version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9.]+)\+([0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(match!.group(1), AppInfo.version);
    expect(int.parse(match.group(2)!), AppInfo.buildNumber);
  });

  test('application ID and name are the same everywhere', () {
    expect(AppInfo.packageId, 'com.sandburstmagic');
    expect(AppInfo.appName, 'Sand Burst Magic');
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "${AppInfo.packageId}"'));
    expect(gradle, contains('namespace = "${AppInfo.packageId}"'));
    expect(gradle, contains('isMinifyEnabled = false'));
    final activity = File(
      'android/app/src/main/kotlin/'
      '${AppInfo.packageId.replaceAll('.', '/')}/MainActivity.kt',
    );
    expect(
      activity.readAsStringSync(),
      contains('package ${AppInfo.packageId}'),
    );
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    expect(
      strings,
      contains('<string name="app_name">${AppInfo.appName}</string>'),
    );
    expect(
      strings,
      contains('<string name="launcher_name">${AppInfo.appName}</string>'),
    );
    expect(AppInfo.websiteUrl, 'https://magivix.com');
    expect(
      AppInfo.playStoreUrl,
      'https://play.google.com/store/apps/details?id=com.sandburstmagic',
    );
    // Test builds are not on Google Play yet: share the website instead.
    expect(AppInfo.shareUrl, AppInfo.websiteUrl);
    expect(AppInfo.contactEmail, 'support@magivix.com');
    expect(AppInfo.privacyPolicyUrl, 'https://magivix.com/privacy-policy/');
    expect(AppInfo.termsUrl, 'https://magivix.com/terms-of-use/');
    // The studio's pages, shared with Block Burst Magic.
    expect(AppInfo.socialLinks, [
      ('Facebook', 'https://www.facebook.com/magivix'),
      ('TikTok', 'https://www.tiktok.com/@magivix'),
      ('Instagram', 'https://www.instagram.com/magivixstudio'),
      ('YouTube', 'https://www.youtube.com/@magivix'),
      ('X', 'https://x.com/magivixstudio'),
    ]);
    expect(AppInfo.removeAdsProductId, 'remove_ads');
  });

  test('every declared asset exists', () {
    for (final f in [
      'assets/fonts/Outfit-Regular.ttf',
      'assets/fonts/Outfit-ExtraBold.ttf',
      'assets/fonts/OFL.txt',
      for (final s in Sfx.values) 'assets/audio/sfx/${s.name}.ogg',
      for (final m in MusicTrack.values) 'assets/audio/music/${m.name}.ogg',
      'store/icon-512.png',
      'assets/images/launch_icon.png',
      'store/feature-graphic-1024x500.png',
      'tool/icon_source/sand_burst_magic_icon_master.png',
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml',
      'android/app/src/main/res/drawable/ic_stat_sandburstmagic.xml',
      for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) ...[
        for (final n in [
          'ic_launcher',
          'ic_launcher_round',
          'ic_launcher_foreground',
          'ic_launcher_background',
          'ic_launcher_monochrome',
        ])
          'android/app/src/main/res/mipmap-$d/$n.png',
        'android/app/src/main/res/drawable-$d/splash_mark.png',
      ],
    ]) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
  });

  test('the Play icon is 512 x 512', () {
    final bytes = File('store/icon-512.png').readAsBytesSync();
    // PNG IHDR: width and height are big-endian at bytes 16..23.
    int be(int o) =>
        (bytes[o] << 24) |
        (bytes[o + 1] << 16) |
        (bytes[o + 2] << 8) |
        bytes[o + 3];
    expect(be(16), 512);
    expect(be(20), 512);
  });
}
