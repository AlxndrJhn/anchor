import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/app_dimensions.dart';
import '../../../core/theme/tokens/app_icon_sizes.dart';
import '../../../core/theme/tokens/app_opacity.dart';
import '../../../core/theme/tokens/app_radius.dart';
import '../../../core/theme/tokens/app_schemes.dart';
import '../../../core/theme/tokens/app_style.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/editor/link_utils.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/settings_card.dart';
import '../../../core/widgets/settings_row.dart';
import '../../../core/widgets/large_title_app_bar.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/network/server_config_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/server_info_provider.dart';
import 'controllers/editor_preferences_controller.dart';
import 'controllers/theme_preferences_controller.dart';
import 'custom_theme_editor.dart';
import '../../sync/data/sync_compatibility.dart';
import '../../../core/update/app_release.dart';
import '../../../core/update/app_updater.dart';
import '../../../core/update/update_sheet.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../picture_search/picture_search.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '';

  /// "Check automatically", once read from storage.
  bool _checkForUpdates = true;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    if (canSelfUpdate) {
      ref.read(preferencesRepositoryProvider).getCheckForUpdates().then((on) {
        if (mounted) setState(() => _checkForUpdates = on);
      });
    }
  }

  Future<void> _checkForUpdatesNow() async {
    final release = await ref.read(updateControllerProvider.notifier).check();
    if (!mounted) return;
    if (release != null) {
      showUpdateSheet(context);
      return;
    }
    final error = ref.read(updateControllerProvider).error;
    if (error != null) {
      AppSnackbar.showError(context, message: error);
    } else {
      AppSnackbar.showSuccess(context, message: 'Anchor is up to date');
    }
  }

  Future<void> _setCheckForUpdates(bool on) async {
    setState(() => _checkForUpdates = on);
    await ref.read(preferencesRepositoryProvider).setCheckForUpdates(on);
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmDialog(
        icon: LucideIcons.logOut,
        title: 'Log Out',
        message:
            'Are you sure you want to log out? Your unsynced notes will stay safe on this device.',
        cancelText: 'Stay',
        confirmText: 'Log Out',
        onConfirm: () async {
          await ref.read(authControllerProvider.notifier).logout();
          // Navigation is handled by the router redirect logic
        },
      ),
    );
  }

  static const _themeModes = [
    (
      ThemeMode.system,
      'System',
      'Follow device settings',
      LucideIcons.smartphone,
    ),
    (ThemeMode.light, 'Light', 'Always use light theme', LucideIcons.sun),
    (ThemeMode.dark, 'Dark', 'Always use dark theme', LucideIcons.moon),
  ];

  static const _styleIcons = {
    AppStyle.standard: LucideIcons.sparkles,
    AppStyle.skeuomorphism: LucideIcons.layers,
    AppStyle.neoBrutalism: LucideIcons.square,
    AppStyle.lofi: LucideIcons.pencil,
  };

  static const _densities = [
    (DisplayDensity.standard, 'More breathing room', LucideIcons.alignLeft),
    (DisplayDensity.compact, 'Fit more on screen', LucideIcons.alignJustify),
  ];

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final currentThemeMode = ref.watch(themeModeControllerProvider);
    final currentDensity = ref.watch(displayDensityControllerProvider);
    final currentScheme = ref.watch(colorSchemeControllerProvider);
    final currentStyle = ref.watch(appStyleControllerProvider);
    final editorPrefs = ref.watch(editorPreferencesControllerProvider);
    final serverUrl = ref.watch(serverUrlProvider);
    final serverInfoAsync = ref.watch(serverInfoProvider);

    return Scaffold(
      body: GradientBackground(
        child: CustomScrollView(
          slivers: [
            LargeTitleAppBar(title: 'Settings'),

            SliverPadding(
              padding: EdgeInsets.all(dims.pagePadding),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Section(
                      title: 'Appearance',
                      icon: LucideIcons.palette,
                      children: [
                        for (final (mode, title, subtitle, icon) in _themeModes)
                          SettingsSelectRow(
                            title: title,
                            subtitle: subtitle,
                            icon: icon,
                            isSelected: currentThemeMode == mode,
                            onTap: () => ref
                                .read(themeModeControllerProvider.notifier)
                                .setThemeMode(mode),
                          ),
                      ],
                    ),

                    _Section(
                      title: 'Colour scheme',
                      icon: LucideIcons.swatchBook,
                      children: [
                        _SchemePicker(
                          selected: currentScheme,
                          // Lo-fi draws in its own greys.
                          note: currentStyle == AppStyle.lofi
                              ? 'Lo-fi draws in pencil greys, whatever the scheme.'
                              : null,
                          onSelected: (id) => ref
                              .read(colorSchemeControllerProvider.notifier)
                              .setScheme(id),
                        ),
                      ],
                    ),

                    const _Section(
                      title: 'Custom theme',
                      icon: LucideIcons.braces,
                      children: [CustomThemeEditor()],
                    ),

                    _Section(
                      title: 'Style',
                      icon: LucideIcons.brush,
                      children: [
                        for (final style in AppStyle.values)
                          SettingsSelectRow(
                            title: style.label,
                            subtitle: style.subtitle,
                            icon: _styleIcons[style]!,
                            isSelected: currentStyle == style,
                            onTap: () => ref
                                .read(appStyleControllerProvider.notifier)
                                .setStyle(style),
                          ),
                      ],
                    ),

                    _Section(
                      title: 'Display density',
                      icon: LucideIcons.scaling,
                      children: [
                        for (final (density, subtitle, icon) in _densities)
                          SettingsSelectRow(
                            title: density.label,
                            subtitle: subtitle,
                            icon: icon,
                            isSelected: currentDensity == density,
                            onTap: () => ref
                                .read(displayDensityControllerProvider.notifier)
                                .setDensity(density),
                          ),
                      ],
                    ),

                    _Section(
                      title: 'Editor',
                      icon: LucideIcons.edit3,
                      children: [
                        SettingsSwitchRow(
                          title: 'Sort checklist items',
                          subtitle:
                              'Automatically move checked checklist items to the bottom',
                          icon: LucideIcons.listChecks,
                          value: editorPrefs.sortChecklistItems,
                          onChanged: (value) => ref
                              .read(
                                editorPreferencesControllerProvider.notifier,
                              )
                              .setSortChecklistItems(value),
                        ),
                        SettingsSwitchRow(
                          title: 'Burn deleted notes',
                          subtitle:
                              'A deleted note burns away where it stood. Off, '
                              'it just goes',
                          icon: LucideIcons.flame,
                          value: editorPrefs.burnDeleted,
                          onChanged: (value) => ref
                              .read(
                                editorPreferencesControllerProvider.notifier,
                              )
                              .setBurnDeleted(value),
                        ),
                      ],
                    ),

                    const _PictureSearchSection(),

                    _Section(
                      title: 'Account',
                      icon: LucideIcons.user,
                      children: [
                        SettingsActionRow(
                          title: 'Edit Profile',
                          subtitle: 'Update your name and profile image',
                          icon: LucideIcons.user,
                          onTap: () => context.push(
                            '/${AppRoutes.settings}/${AppRoutes.editProfile}',
                          ),
                        ),
                        SettingsActionRow(
                          title: 'Change Password',
                          subtitle: 'Update your account password',
                          icon: LucideIcons.lock,
                          onTap: () => context.push(
                            '/${AppRoutes.settings}/${AppRoutes.changePassword}',
                          ),
                        ),
                        SettingsActionRow(
                          title: 'View Logs',
                          subtitle: 'Diagnostic logs for support and debugging',
                          icon: LucideIcons.fileText,
                          onTap: () => context.push(
                            '/${AppRoutes.settings}/${AppRoutes.viewLogs}',
                          ),
                        ),
                        SettingsActionRow(
                          title: 'Log Out',
                          subtitle: 'Sign out of your account',
                          icon: LucideIcons.logOut,
                          isDestructive: true,
                          onTap: _showLogoutDialog,
                        ),
                      ],
                    ),

                    if (canSelfUpdate)
                      _Section(
                        title: 'Updates',
                        icon: LucideIcons.download,
                        children: [
                          SettingsActionRow(
                            title: 'Check for updates',
                            subtitle:
                                ref.watch(updateControllerProvider).status ==
                                    UpdateStatus.checking
                                ? 'Checking…'
                                : 'This is build $installedBuild of '
                                      '$updateRepository',
                            icon: LucideIcons.refreshCw,
                            onTap: _checkForUpdatesNow,
                          ),
                          SettingsSwitchRow(
                            title: 'Check automatically',
                            subtitle:
                                'Look for a new release when Anchor starts',
                            icon: LucideIcons.bellRing,
                            value: _checkForUpdates,
                            onChanged: _setCheckForUpdates,
                          ),
                        ],
                      ),

                    _Section(
                      title: 'Support',
                      icon: LucideIcons.heart,
                      children: [
                        SettingsActionRow(
                          title: 'Buy me a coffee',
                          subtitle: 'Support the development of Anchor',
                          icon: LucideIcons.coffee,
                          onTap: () => launchExternal(
                            context,
                            'https://www.buymeacoffee.com/zahid',
                          ),
                        ),
                      ],
                    ),

                    _AboutFooter(
                      appVersion: _appVersion,
                      serverUrl: serverUrl,
                      serverInfo: serverInfoAsync,
                    ),
                    SizedBox(height: dims.pagePadding),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A grid of colour scheme swatches, each in the current brightness.
class _SchemePicker extends StatelessWidget {
  const _SchemePicker({
    required this.selected,
    required this.onSelected,
    this.note,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    return Padding(
      padding: EdgeInsets.all(dims.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final columns = constraints.maxWidth > 420 ? 4 : 3;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final scheme in [anchorScheme, ...appSchemes])
                    SizedBox(
                      width: width,
                      child: _SchemeTile(
                        scheme: scheme,
                        isSelected: scheme.id == selected,
                        onTap: () => onSelected(scheme.id),
                      ),
                    ),
                ],
              );
            },
          ),
          if (note != null) ...[
            SizedBox(height: dims.sm),
            Text(
              note!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: AppOpacity.secondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SchemeTile extends StatelessWidget {
  const _SchemeTile({
    required this.scheme,
    required this.isSelected,
    required this.onTap,
  });

  final AppScheme scheme;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = scheme.of(theme.brightness);
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${scheme.name} colour scheme',
      child: Material(
        color: palette.background,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.tertiary
                : palette.foreground.withValues(alpha: 0.12),
            width: isSelected ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A miniature card: a title line in the ink, an accent dot.
                Container(
                  height: 34,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius: AppRadius.xsBorder,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 5,
                              width: 34,
                              color: palette.foreground,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 4,
                              width: 24,
                              color: palette.mutedForeground,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        scheme.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: palette.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        LucideIcons.check,
                        size: 14,
                        color: palette.foreground,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The opt-in to finding notes by what their pictures show, with how far
/// the server is; shown when the server offers it.
class _PictureSearchSection extends ConsumerStatefulWidget {
  const _PictureSearchSection();

  @override
  ConsumerState<_PictureSearchSection> createState() =>
      _PictureSearchSectionState();
}

class _PictureSearchSectionState extends ConsumerState<_PictureSearchSection> {
  Timer? _poll;
  bool _saving = false;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Follows the download and the indexing while they run.
  void _followProgress(PictureSearchStatus status) {
    if (!status.isBusy) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    _poll ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) ref.invalidate(pictureSearchStatusProvider);
    });
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() => _saving = true);
    try {
      await ref.read(pictureSearchRepositoryProvider).setEnabled(enabled);
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Couldn’t change picture search',
        );
      }
    }
    if (!mounted) return;
    ref.invalidate(pictureSearchStatusProvider);
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(pictureSearchStatusProvider).value;
    ref.listen(pictureSearchStatusProvider, (_, next) {
      if (next.value case final status?) _followProgress(status);
    });
    if (status == null || !status.available) return const SizedBox.shrink();
    final progress = status.progressText;
    return _Section(
      title: 'Search',
      icon: LucideIcons.search,
      children: [
        SettingsSwitchRow(
          title: 'Find pictures by what they show',
          subtitle:
              'Search for “Sonnenuntergang am Meer” or “receipt” and find '
              'notes with such pictures, in most languages. Your server '
              'downloads a model once (about 380 MB) and looks at each '
              'picture; nothing leaves your server.'
              '${progress == null ? '' : '\n\n$progress'}',
          icon: LucideIcons.images,
          value: status.enabled,
          onChanged: (on) {
            if (!_saving) _setEnabled(on);
          },
        ),
      ],
    );
  }
}

/// A titled settings group: header, card, and dividers between the rows.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return Padding(
      padding: EdgeInsets.only(bottom: dims.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: title, icon: icon),
          SizedBox(height: dims.sm),
          SettingsCard(
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SettingsDivider(),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// App version, and where the app is pointed, in fine print.
class _AboutFooter extends StatelessWidget {
  const _AboutFooter({
    required this.appVersion,
    required this.serverUrl,
    required this.serverInfo,
  });

  final String appVersion;
  final String? serverUrl;
  final AsyncValue<ServerInfo?> serverInfo;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: dims.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AboutRow(
            icon: LucideIcons.info,
            text: 'App v${appVersion.isNotEmpty ? appVersion : '...'}',
          ),
          if (serverUrl != null) ...[
            SizedBox(height: dims.xxs),
            serverInfo.when(
              loading: () => const _AboutRow(
                icon: LucideIcons.package,
                text: 'Server v...',
              ),
              error: (_, _) => _AboutRow(
                icon: LucideIcons.serverOff,
                text: "Can't reach $serverUrl",
              ),
              data: (info) => info == null
                  ? _AboutRow(
                      icon: LucideIcons.serverOff,
                      text: "Can't reach $serverUrl",
                    )
                  : Column(
                      children: [
                        _AboutRow(
                          icon: LucideIcons.package,
                          text: 'Server v${info.version}',
                        ),
                        SizedBox(height: dims.xxs),
                        _AboutRow(
                          icon: LucideIcons.server,
                          text: 'Connected to $serverUrl',
                        ),
                        if (compatibilityFor(info.protocols).isMismatch) ...[
                          SizedBox(height: dims.xxs),
                          _AboutRow(
                            icon: LucideIcons.triangleAlert,
                            text: 'Sync paused, versions incompatible',
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;

  /// Overrides the muted default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = color ?? theme.colorScheme.onSurface;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: AppIconSizes.xs,
          color: onSurface.withValues(alpha: AppOpacity.disabled),
        ),
        SizedBox(width: context.dims.xxs),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: onSurface.withValues(alpha: AppOpacity.secondary),
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
