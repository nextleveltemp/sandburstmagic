import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app_info.dart';
import '../../data/models.dart';
import '../../l10n/strings.dart';
import '../../state/app_services.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/links.dart';
import '../widgets/reminders.dart';
import 'tutorial_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _rate(BuildContext context) async {
    final s = Strings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await AppScope.read(context).review.openStoreListing();
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(s.storeUnavailable)));
    }
  }

  Future<void> _shareApp(BuildContext context) async {
    final s = Strings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await AppScope.read(
      context,
    ).share.shareText(s.shareAppText(AppInfo.shareUrl));
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(s.shareFailed)));
  }

  Future<void> _buyRemoveAds(BuildContext context) async {
    final s = Strings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final purchases = AppScope.read(context).purchases;
    final started = purchases.canBuy && await purchases.buyRemoveAds();
    if (!started) {
      messenger.showSnackBar(SnackBar(content: Text(s.purchaseUnavailable)));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final s = Strings.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.restoreStarted)));
    await AppScope.read(context).purchases.restore();
  }

  Future<void> _reset(BuildContext context) async {
    final s = Strings.of(context);
    final services = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ResetDialog(),
    );
    if (ok != true) return;
    await services.resetProgress();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.resetDone)));
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final services = AppScope.of(context);
    final palette = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          services.settings,
          services.ads,
          services.purchases,
        ]),
        builder: (context, _) {
          final v = services.settings.value;
          void change(AppSettings Function(AppSettings) f) {
            services.settings.update(f);
            services.applySettings();
          }

          return ListView(
            padding: withSystemInsets(
              context,
              const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xxl),
            ),
            children: [
              SectionTitle(s.sound),
              _Group(
                children: [
                  SwitchListTile(
                    key: const ValueKey('sfx-switch'),
                    title: Text(s.soundEffects),
                    value: v.sfx,
                    onChanged: (x) => change((a) => a.copyWith(sfx: x)),
                  ),
                  SwitchListTile(
                    key: const ValueKey('music-switch'),
                    title: Text(s.music),
                    subtitle: Text(s.musicHint),
                    value: v.music,
                    onChanged: (x) => change((a) => a.copyWith(music: x)),
                  ),
                  ListTile(
                    title: Text(s.volume),
                    subtitle: Slider(
                      value: v.volume,
                      divisions: 10,
                      label: '${(v.volume * 100).round()}%',
                      semanticFormatterCallback: (x) => '${(x * 100).round()}%',
                      onChanged: (x) => change((a) => a.copyWith(volume: x)),
                    ),
                  ),
                  SwitchListTile(
                    key: const ValueKey('haptics-switch'),
                    title: Text(s.haptics),
                    subtitle: Text(s.hapticsHint),
                    value: v.haptics,
                    onChanged: (x) => change((a) => a.copyWith(haptics: x)),
                  ),
                ],
              ),
              SectionTitle(s.display),
              _Group(
                children: [
                  ListTile(
                    title: Text(s.appearance),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: Space.sm),
                      child: SegmentedButton<ThemePreference>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: ThemePreference.system,
                            label: Text(s.appearanceSystem),
                          ),
                          ButtonSegment(
                            value: ThemePreference.dark,
                            label: Text(s.appearanceDark),
                          ),
                          ButtonSegment(
                            value: ThemePreference.light,
                            label: Text(s.appearanceLight),
                          ),
                        ],
                        selected: {v.themePreference},
                        onSelectionChanged: (sel) => change(
                          (a) => a.copyWith(themePreference: sel.first),
                        ),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    key: const ValueKey('motion-switch'),
                    title: Text(s.reduceMotion),
                    subtitle: Text(s.reduceMotionHint),
                    value: v.reduceMotion,
                    onChanged: (x) =>
                        change((a) => a.copyWith(reduceMotion: x)),
                  ),
                  SwitchListTile(
                    key: const ValueKey('goals-switch'),
                    title: Text(s.showMissions),
                    subtitle: Text(s.showMissionsHint),
                    value: v.showDailyGoals,
                    onChanged: (x) =>
                        change((a) => a.copyWith(showDailyGoals: x)),
                  ),
                ],
              ),
              SectionTitle(s.remindersHeading),
              _Group(
                children: [
                  SwitchListTile(
                    key: const ValueKey('reminder-switch'),
                    title: Text(s.reminder),
                    subtitle: Text(s.reminderHint),
                    value: v.reminder,
                    onChanged: (x) {
                      if (x) {
                        turnOnReminders(context);
                      } else {
                        change((a) => a.copyWith(reminder: false));
                      }
                    },
                  ),
                  ListTile(
                    enabled: v.reminder,
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(s.reminderTime),
                    trailing: Text(
                      formatReminderTime(context, v.reminderMinutes),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => pickReminderTime(context),
                  ),
                ],
              ),
              SectionTitle(s.help),
              _Group(
                children: [
                  ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: Text(s.howToPlay),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      FadeScaleRoute<void>(
                        builder: (_) => const TutorialScreen(firstRun: false),
                      ),
                    ),
                  ),
                ],
              ),
              SectionTitle(s.privacy),
              _Group(
                children: [
                  // Both open the pages on magivix.com (the in-app text if
                  // nothing on the phone can open a web page).
                  ListTile(
                    key: const ValueKey('settings-privacy'),
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(s.privacyPolicy),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => openPrivacy(context),
                  ),
                  ListTile(
                    key: const ValueKey('settings-terms'),
                    leading: const Icon(Icons.gavel_rounded),
                    title: Text(s.termsOfUse),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => openTerms(context),
                  ),
                  if (services.ads.privacyOptionsRequired)
                    ListTile(
                      leading: const Icon(Icons.tune_rounded),
                      title: Text(s.privacyChoices),
                      onTap: services.ads.showPrivacyOptions,
                    ),
                ],
              ),
              if (services.ads.adsEnabled) ...[
                SectionTitle(s.removeAdsHeading),
                _Group(
                  children: [
                    if (services.purchases.adsRemoved)
                      ListTile(
                        key: const ValueKey('settings-ads-removed'),
                        leading: Icon(
                          Icons.verified_rounded,
                          color: palette.gold,
                        ),
                        title: Text(s.adsRemovedTitle),
                        subtitle: Text(s.adsRemovedHint),
                      )
                    else ...[
                      ListTile(
                        key: const ValueKey('settings-remove-ads'),
                        leading: Icon(Icons.block_rounded, color: palette.gold),
                        title: Text(s.removeAds),
                        subtitle: Text(
                          s.removeAdsHint(services.purchases.price),
                        ),
                        trailing: services.purchases.busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: services.purchases.busy
                            ? null
                            : () => _buyRemoveAds(context),
                      ),
                      ListTile(
                        key: const ValueKey('settings-restore'),
                        leading: const Icon(Icons.restore_rounded),
                        title: Text(s.restorePurchase),
                        subtitle: Text(s.restorePurchaseHint),
                        onTap: () => _restore(context),
                      ),
                    ],
                  ],
                ),
              ],
              SectionTitle(s.about),
              _Group(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: Text(s.about),
                    subtitle: Text(s.version(AppInfo.version)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      FadeScaleRoute<void>(builder: (_) => const AboutScreen()),
                    ),
                  ),
                  // Only once the Play listing exists (see AppInfo).
                  if (AppInfo.storeListed)
                    ListTile(
                      leading: const Icon(Icons.star_rounded),
                      title: Text(s.rateApp),
                      subtitle: Text(s.rateAppHint),
                      trailing: const Icon(Icons.open_in_new_rounded),
                      onTap: () => _rate(context),
                    ),
                  ListTile(
                    leading: const Icon(Icons.share_rounded),
                    title: Text(s.shareApp),
                    subtitle: Text(s.shareAppHint),
                    onTap: () => _shareApp(context),
                  ),
                ],
              ),
              SectionTitle(s.studioHeading),
              _Group(
                children: [
                  ListTile(
                    key: const ValueKey('studio-website'),
                    leading: const Icon(Icons.language_rounded),
                    title: Text(s.visitWebsite),
                    subtitle: Text(Uri.parse(AppInfo.websiteUrl).host),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => openWebsite(context),
                  ),
                  const _SocialRow(),
                  if (AppInfo.contactEmail.isNotEmpty)
                    ListTile(
                      key: const ValueKey('settings-feedback'),
                      leading: const Icon(Icons.mail_outline_rounded),
                      title: Text(s.sendFeedback),
                      subtitle: Text(s.sendFeedbackHint),
                      trailing: const Icon(Icons.open_in_new_rounded),
                      onTap: () => openFeedbackEmail(context),
                    ),
                ],
              ),
              SectionTitle(s.data),
              _Group(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_rounded,
                      color: palette.danger,
                    ),
                    title: Text(
                      s.resetProgress,
                      style: TextStyle(color: palette.danger),
                    ),
                    onTap: () => _reset(context),
                  ),
                ],
              ),
              if (services.ads.usingTestAds) ...[
                const SizedBox(height: Space.lg),
                Text(
                  s.testAdsNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(Radii.lg),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// Reset requires typing a confirmation word, so progress is never lost by an
/// accidental tap.
class _ResetDialog extends StatefulWidget {
  const _ResetDialog();

  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<_ResetDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final palette = AppPalette.of(context);
    final ok = _field.text.trim().toUpperCase() == s.resetWord;
    return AlertDialog(
      // Scrolls when the keyboard or large text leaves little room.
      scrollable: true,
      title: Text(s.resetTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.resetBody),
          const SizedBox(height: Space.lg),
          TextField(
            controller: _field,
            autofocus: true,
            decoration: InputDecoration(labelText: s.resetConfirmField),
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) {
              if (v.trim().toUpperCase() == s.resetWord) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(s.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: palette.danger),
          onPressed: ok ? () => Navigator.of(context).pop(true) : null,
          child: Text(s.resetAction),
        ),
      ],
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.about)),
      body: ListView(
        padding: withSystemInsets(context, const EdgeInsets.all(Space.xl)),
        children: [
          const Center(child: Wordmark(height: 36)),
          const SizedBox(height: Space.lg),
          Center(
            child: Text(
              s.gameByStudio,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: Space.xs),
          Center(
            child: Text(
              s.version(AppInfo.version),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: Space.xl),
          Text(s.aboutBody, style: theme.textTheme.bodyLarge),
          const SizedBox(height: Space.xl),
          Text(s.studioHeading, style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.sm),
          Text(s.studioBody, style: theme.textTheme.bodyMedium),
          const SizedBox(height: Space.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => openWebsite(context),
              icon: const Icon(Icons.language_rounded),
              label: Text(Uri.parse(AppInfo.websiteUrl).host),
            ),
          ),
          const SizedBox(height: Space.lg),
          Text(s.credits, style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.sm),
          Text(s.creditsBody, style: theme.textTheme.bodyMedium),
          const SizedBox(height: Space.xl),
          OutlinedButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: s.appName,
              applicationVersion: AppInfo.version,
            ),
            child: Text(s.licenses),
          ),
        ],
      ),
    );
  }
}

/// The Terms of Use in short, inside the app (the full text is on the
/// website once [AppInfo.termsUrl] is set).
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final theme = Theme.of(context);
    final adsOn = AppScope.of(context).ads.adsEnabled;
    final body = theme.textTheme.bodyLarge;
    return Scaffold(
      appBar: AppBar(title: Text(s.termsOfUse)),
      body: ListView(
        key: const ValueKey('terms-screen'),
        padding: withSystemInsets(context, const EdgeInsets.all(Space.xl)),
        children: [
          Text(s.termsHeading, style: theme.textTheme.titleLarge),
          for (final p in [
            s.termsBodyIntro,
            s.termsBodyUse,
            if (adsOn) s.termsBodyAds,
            s.termsBodyPurchases,
            s.termsBodyProgress,
            s.termsBodyWarranty,
            s.termsBodyChanges,
          ]) ...[const SizedBox(height: Space.lg), Text(p, style: body)],
          if (AppInfo.termsUrl.isNotEmpty) ...[
            const SizedBox(height: Space.xl),
            OutlinedButton(
              onPressed: () => openUrl(context, AppInfo.termsUrl),
              child: Text(s.termsFull),
            ),
          ],
        ],
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final theme = Theme.of(context);
    final services = AppScope.of(context);
    final adsOn = services.ads.adsEnabled;
    return Scaffold(
      appBar: AppBar(title: Text(s.privacyPolicy)),
      body: ListView(
        padding: withSystemInsets(context, const EdgeInsets.all(Space.xl)),
        children: [
          Text(s.privacyHeading, style: theme.textTheme.titleLarge),
          const SizedBox(height: Space.lg),
          Text(s.privacyBodyGame, style: theme.textTheme.bodyLarge),
          const SizedBox(height: Space.lg),
          Text(
            adsOn ? s.privacyBodyAds : s.privacyBodyNoAds,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: Space.lg),
          Text(s.privacyBodyFeatures, style: theme.textTheme.bodyLarge),
          const SizedBox(height: Space.lg),
          Text(s.privacyBodyReset, style: theme.textTheme.bodyLarge),
          if (services.ads.privacyOptionsRequired) ...[
            const SizedBox(height: Space.xl),
            OutlinedButton(
              onPressed: services.ads.showPrivacyOptions,
              child: Text(s.privacyChoices),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Follow us": the studio's Facebook, TikTok, Instagram, YouTube and X
/// pages as brand icons under "Visit our website", spread across the row so
/// they fit on the smallest phones (as in Block Burst Magic).
class _SocialRow extends StatelessWidget {
  const _SocialRow();

  static const _brands = <String, (FaIconData, Color?)>{
    'Facebook': (FontAwesomeIcons.facebook, Color(0xFF1877F2)),
    // TikTok's and X's logos are black or white: they follow the text colour.
    'TikTok': (FontAwesomeIcons.tiktok, null),
    'Instagram': (FontAwesomeIcons.instagram, Color(0xFFE4405F)),
    'YouTube': (FontAwesomeIcons.youtube, Color(0xFFFF0000)),
    'X': (FontAwesomeIcons.xTwitter, null),
  };

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('settings-social'),
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.sm,
        Space.lg,
        Space.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.followUs, style: theme.textTheme.bodyLarge),
          const SizedBox(height: Space.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final (name, url) in AppInfo.socialLinks)
                IconButton(
                  key: ValueKey('social-${name.toLowerCase()}'),
                  tooltip: name,
                  iconSize: 26,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: FaIcon(
                    _brands[name]!.$1,
                    color: _brands[name]!.$2 ?? theme.colorScheme.onSurface,
                  ),
                  onPressed: () {
                    if (url.isNotEmpty) {
                      openUrl(context, url);
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(content: Text(s.socialComingSoon(name))),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
