import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_info.dart';
import '../../l10n/strings.dart';
import '../screens/settings_screen.dart' show PrivacyScreen, TermsScreen;
import 'common.dart';

/// How links leave the app. Tests replace this to see which address a
/// button opens without a real browser.
@visibleForTesting
Future<bool> Function(Uri uri) launchExternal = (uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Opens [uri] outside the app (browser or email app). Never throws; shows
/// [failMessage] if nothing could open it.
Future<bool> openExternal(
  BuildContext context,
  Uri uri,
  String failMessage,
) async {
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    ok = await launchExternal(uri);
  } catch (e) {
    debugPrint('Could not open $uri: $e');
  }
  if (!ok) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(failMessage)));
  }
  return ok;
}

Future<bool> openWebsite(BuildContext context) => openExternal(
  context,
  Uri.parse(AppInfo.websiteUrl),
  Strings.of(context).linkFailed,
);

/// "Send feedback": an email to [AppInfo.contactEmail]
/// (support@magivix.com), with the app version in the subject.
Future<bool> openFeedbackEmail(BuildContext context) {
  final s = Strings.of(context);
  return openExternal(
    context,
    Uri(
      scheme: 'mailto',
      path: AppInfo.contactEmail,
      query:
          'subject=${Uri.encodeComponent(s.feedbackSubject(AppInfo.version))}',
    ),
    s.emailFailed,
  );
}

Future<bool> openUrl(BuildContext context, String url) =>
    openExternal(context, Uri.parse(url), Strings.of(context).linkFailed);

/// Terms of Use: the published page on magivix.com, or the short in-app
/// notice if nothing on the phone can open it.
Future<void> openTerms(BuildContext context) async {
  if (AppInfo.termsUrl.isNotEmpty && await openUrl(context, AppInfo.termsUrl)) {
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(
    context,
  ).push(FadeScaleRoute<void>(builder: (_) => const TermsScreen()));
}

/// Privacy Policy: the published page on magivix.com, or the in-app summary
/// if nothing on the phone can open it.
Future<void> openPrivacy(BuildContext context) async {
  if (AppInfo.privacyPolicyUrl.isNotEmpty &&
      await openUrl(context, AppInfo.privacyPolicyUrl)) {
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(
    context,
  ).push(FadeScaleRoute<void>(builder: (_) => const PrivacyScreen()));
}
