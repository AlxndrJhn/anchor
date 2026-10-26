import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/context_extensions.dart';
import '../theme/tokens/app_icon_sizes.dart';
import '../theme/tokens/app_radius.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/editor/link_utils.dart';
import 'app_updater.dart';

/// "Update available" above the notes, while there's a newer release the
/// user hasn't put off.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateControllerProvider);
    final release = update.release;
    if (!update.showBanner || release == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final dims = context.dims;
    final ink = theme.colorScheme.onPrimaryContainer;
    return Padding(
      padding: EdgeInsets.only(bottom: dims.sm),
      child: Material(
        color: theme.colorScheme.primaryContainer,
        borderRadius: AppRadius.mdBorder,
        child: InkWell(
          borderRadius: AppRadius.mdBorder,
          onTap: () => showUpdateSheet(context),
          child: Padding(
            padding: EdgeInsets.fromLTRB(dims.sm, dims.xs, dims.xs, dims.xs),
            child: Row(
              children: [
                Icon(LucideIcons.download, size: AppIconSizes.md, color: ink),
                SizedBox(width: dims.sm),
                Expanded(
                  child: Text(
                    'Update available: ${release.tag}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(updateControllerProvider.notifier).dismiss(),
                  style: TextButton.styleFrom(foregroundColor: ink),
                  child: const Text('Later'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showUpdateSheet(BuildContext context) =>
    AppBottomSheet.show(context, builder: (context) => const UpdateSheet());

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
    final theme = Theme.of(context);
    final dims = context.dims;
    if (release == null) return const SizedBox.shrink();

    final downloading = update.status == UpdateStatus.downloading;
    final changes = release.changes;
    return AppBottomSheet(
      icon: LucideIcons.download,
      title: 'Update available',
      subtitle: release.tag,
      maxHeightFactor: 0.85,
      contentPadding: EdgeInsets.fromLTRB(
        dims.pagePadding,
        0,
        dims.pagePadding,
        dims.pagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (changes.isNotEmpty) ...[
            Text('What’s new', style: theme.textTheme.titleSmall),
            SizedBox(height: dims.xs),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final change in changes.take(_shownChanges))
                      Padding(
                        padding: EdgeInsets.only(bottom: dims.xxs),
                        child: Text(
                          '•  $change',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    if (changes.length > _shownChanges)
                      Text(
                        'and ${changes.length - _shownChanges} more',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: dims.md),
          ],
          if (update.error != null) ...[
            Text(
              update.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            SizedBox(height: dims.sm),
          ],
          if (downloading) ...[
            LinearProgressIndicator(value: update.progress),
            SizedBox(height: dims.xs),
            Text(
              'Downloading… ${(update.progress * 100).round()}%',
              style: theme.textTheme.bodySmall,
            ),
          ] else
            FilledButton.icon(
              onPressed: () =>
                  ref.read(updateControllerProvider.notifier).install(),
              icon: const Icon(LucideIcons.download, size: 18),
              label: Text(
                release.apkSize > 0
                    ? 'Download and install '
                          '(${(release.apkSize / 1048576).toStringAsFixed(0)} MB)'
                    : 'Download and install',
              ),
            ),
          SizedBox(height: dims.xs),
          TextButton(
            onPressed: () => launchExternal(context, release.pageUrl),
            child: const Text('View the release on GitHub'),
          ),
        ],
      ),
    );
  }
}
