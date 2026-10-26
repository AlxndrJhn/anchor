import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../links/link_utils.dart';
import '../theme/app_typography.dart';
import '../theme/context_extensions.dart';
import '../widgets/anchor_sheet.dart';
import '../widgets/app_buttons.dart';
import '../widgets/notice.dart';
import 'app_updater.dart';

String updateErrorText(UpdateError error, AppLocalizations l10n) =>
    switch (error) {
      UpdateError.check => l10n.updateCheckFailed,
      UpdateError.download => l10n.updateDownloadFailed,
    };

/// "Update available" above the notes, while there's a newer release the
/// user hasn't put off.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key, this.padding = EdgeInsets.zero});

  /// Applied only while the banner shows.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateControllerProvider);
    final release = update.release;
    if (!update.showBanner || release == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      padding: padding,
      child: Notice(
        icon: LucideIcons.download,
        title: l10n.updateAvailable,
        text: release.tag,
        action: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(
              label: l10n.updateSeeWhatsNew,
              size: AppButtonSize.small,
              isExpanded: false,
              onPressed: () => showUpdateSheet(context),
            ),
            AppButton(
              label: l10n.commonLater,
              kind: AppButtonKind.secondary,
              size: AppButtonSize.small,
              isExpanded: false,
              onPressed: () =>
                  ref.read(updateControllerProvider.notifier).dismiss(),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showUpdateSheet(BuildContext context) => showAnchorSheet<void>(
  context,
  semanticLabel: context.l10n.updateAvailable,
  builder: (context) => const UpdateSheet(),
);

/// The newer release: what changed, and a button that downloads and
/// installs it.
class UpdateSheet extends ConsumerWidget {
  const UpdateSheet({super.key});

  /// Change lines shown before "and N more".
  static const _shownChanges = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateControllerProvider);
    final release = update.release;
    if (release == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colors = context.anchor;
    final downloading = update.status == UpdateStatus.downloading;
    final changes = release.changes;
    final megabytes = (release.apkSize / 1048576).round();
    final line = AppTypography.secondary.copyWith(color: colors.appText);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: l10n.updateAvailable, subtitle: release.tag),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: context.density.space8,
              children: [
                if (changes.isNotEmpty) ...[
                  Text(
                    l10n.updateWhatsNew,
                    style: AppTypography.row.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.appText,
                    ),
                  ),
                  for (final change in changes.take(_shownChanges))
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        Text('•', style: line),
                        Expanded(child: Text(change, style: line)),
                      ],
                    ),
                  if (changes.length > _shownChanges)
                    Text(
                      l10n.updateMoreChanges(changes.length - _shownChanges),
                      style: AppTypography.secondary.copyWith(
                        color: colors.appMuted,
                      ),
                    ),
                ],
                if (update.error case final error?)
                  Notice(
                    kind: NoticeKind.danger,
                    icon: LucideIcons.circleAlert,
                    text: updateErrorText(error, l10n),
                  ),
              ],
            ),
          ),
        ),
        SheetFooter(
          children: [
            AppButton(
              label: l10n.updateViewRelease,
              icon: LucideIcons.arrowUpRight,
              kind: AppButtonKind.secondary,
              onPressed: release.pageUrl.isEmpty
                  ? null
                  : () => launchExternal(context, release.pageUrl),
            ),
            AppButton(
              label: megabytes > 0
                  ? l10n.updateInstallSize(megabytes)
                  : l10n.updateInstall,
              icon: LucideIcons.download,
              isBusy: downloading,
              busyLabel: l10n.updateDownloading(
                (update.progress * 100).round(),
              ),
              onPressed: () =>
                  ref.read(updateControllerProvider.notifier).install(),
            ),
          ],
        ),
      ],
    );
  }
}
