import 'package:anchor/core/widgets/destruction/destruction.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:anchor/features/notes/domain/note_history.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/data/repository/note_attachments_repository.dart';
import 'package:anchor/core/theme/context_extensions.dart';
import 'package:anchor/core/theme/tokens/app_icon_sizes.dart';
import 'package:anchor/core/theme/tokens/app_radius.dart';
import 'package:anchor/core/theme/tokens/app_style.dart';
import 'package:anchor/core/widgets/image_shimmer.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/features/settings/presentation/controllers/editor_preferences_controller.dart';
import 'package:anchor/features/notes/presentation/notes_view_options.dart';
import 'package:anchor/features/notes/presentation/widgets/note_attachments_gallery.dart';
import 'package:anchor/core/widgets/quill_preview.dart';
import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:anchor/features/tags/presentation/widgets/tag_chip.dart';
import 'package:anchor/features/notes/presentation/widgets/note_background.dart';
import 'package:anchor/features/notes/presentation/widgets/reminder_chip.dart';
import 'package:anchor/features/notes/presentation/widgets/share_note_sheet.dart';
import 'package:anchor/core/widgets/app_bottom_sheet.dart';
import 'package:anchor/core/theme/tokens/app_opacity.dart';
import 'package:anchor/features/note_locks/presentation/note_lock_session.dart';

/// Lines of body text shown under the title.
const _previewMaxLines = 6;

/// Aspect ratio of a note card carrying exactly one image.
const _singleImageAspect = 16 / 9;

class NoteCard extends ConsumerWidget {
  final Note note;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final String? datePrefix;
  final List<Widget>? trailingActions;

  const NoteCard({
    super.key,
    required this.note,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onTap,
    this.datePrefix,
    this.trailingActions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      // Deleted, the card burns away where it stands.
      Destructible(id: note.id, child: _card(context, ref));

  Widget _card(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsControllerProvider);
    final serverUrl = ref.watch(serverUrlProvider);
    final theme = Theme.of(context);
    final dims = context.dims;
    final showPictures =
        ref.watch(notesViewOptionsProvider).value?.showPictures ?? true;
    // Locked and not opened this session: the title only, no text or
    // pictures.
    final isHidden = isNoteHidden(note, ref.watch(noteLockSessionProvider));
    final hasImages =
        !isHidden && showPictures && note.imagePreviewData.isNotEmpty;
    final hasContent =
        isHidden || (note.content != null && note.content!.isNotEmpty);
    final showBadge = isSelectionMode && !hasImages;
    final showPin = !isSelectionMode && !hasImages && note.isPinned;
    final showTopRow = note.hasTitle || hasContent || showBadge || showPin;
    // Items can be ticked from the card, without opening the note.
    final canTick =
        !isSelectionMode && note.canEdit && note.isActive && !note.isArchived;
    final Widget preview = isHidden
        ? const _LockedLine()
        : QuillPreview(
            content: note.content,
            maxLines: _previewMaxLines,
            onToggleItem: canTick
                ? (line) => ref
                      .read(notesRepositoryProvider)
                      .toggleChecklistItem(
                        note.id,
                        line,
                        sort: ref
                            .read(editorPreferencesControllerProvider)
                            .sortChecklistItems,
                        // So several items can be ticked in a row.
                        keepAt: keptPlace(note),
                      )
                : null,
          );

    final cardColor = note.background != null
        ? NoteBackground.resolveColor(context, note.background)
        : theme.cardTheme.color ?? theme.colorScheme.surface;

    final style = context.styleTokens;
    final selectedSide = BorderSide(
      color: style.style == AppStyle.standard
          ? theme.colorScheme.primary
          : theme.colorScheme.tertiary,
      width: style.style == AppStyle.neoBrutalism ? 3 : 2,
    );

    return Hero(
      tag: 'note_${note.id}',
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: style.cardRadius,
            boxShadow: style.cardShadows,
          ),
          child: Card(
            color: cardColor,
            clipBehavior: Clip.antiAlias,
            elevation: isSelected && style.cardShadows.isEmpty ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: style.cardRadius,
              side: isSelected ? selectedSide : style.cardSide,
            ),
            child: _PickedTint(
              isSelected: isSelected,
              color: theme.colorScheme.primary,
              child: InkWell(
                onTap:
                    onTap ?? () => context.go('/note/${note.id}', extra: note),
                onLongPress: onLongPress,
                borderRadius: style.cardRadius,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImages)
                      Stack(
                        children: [
                          _NoteImagePreviews(
                            grayscale: style.plainNotes,
                            previews: note.imagePreviewData,
                            // Straight to the picture, as on the web.
                            onOpen: isSelectionMode
                                ? null
                                : (id) => showNotePicture(
                                    context,
                                    ref,
                                    noteId: note.id,
                                    attachmentId: id,
                                  ),
                          ),
                          if (isSelectionMode || note.isPinned)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: isSelectionMode
                                  ? _SelectionBadge(isSelected: isSelected)
                                  : _PinBadge(),
                            ),
                        ],
                      ),
                    NoteBackground(
                      styleId: note.background,
                      borderRadius: BorderRadius.zero,
                      child: Padding(
                        padding: dims.noteCardPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showTopRow)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showBadge) ...[
                                    _SelectionBadge(isSelected: isSelected),
                                    SizedBox(width: dims.sm),
                                  ],
                                  Expanded(
                                    child: note.hasTitle
                                        ? Text(
                                            note.title,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: -0.3,
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : preview,
                                  ),
                                  if (showPin) ...[
                                    SizedBox(width: dims.xs),
                                    Icon(
                                      LucideIcons.pin,
                                      size: AppIconSizes.sm,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ],
                                  // Opened this session: shown, but still
                                  // locked.
                                  if (note.isLocked && !isHidden) ...[
                                    SizedBox(width: dims.xs),
                                    Icon(
                                      LucideIcons.lockOpen,
                                      key: const ValueKey('card-unlocked'),
                                      size: AppIconSizes.sm,
                                      color: theme.colorScheme.onSurface
                                          .withValues(
                                            alpha: AppOpacity.secondary,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            if (note.hasTitle && hasContent) ...[
                              SizedBox(height: dims.noteCardTitleGap),
                              preview,
                            ],
                            if (note.tagIds.isNotEmpty) ...[
                              if (showTopRow)
                                SizedBox(height: dims.noteCardTagGap),
                              tagsAsync.when(
                                data: (allTags) {
                                  final userNoteTags = allTags
                                      .where((t) => note.tagIds.contains(t.id))
                                      .toList();
                                  if (userNoteTags.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  final displayedTags = userNoteTags
                                      .take(3)
                                      .toList();
                                  final remaining =
                                      userNoteTags.length -
                                      displayedTags.length;
                                  return Wrap(
                                    spacing: dims.xxs,
                                    runSpacing: dims.xxs,
                                    children: [
                                      ...displayedTags.map(
                                        (tag) =>
                                            TagChip(tag: tag, selected: false),
                                      ),
                                      if (remaining > 0)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: dims.xs,
                                            vertical: dims.xxs,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            borderRadius: AppRadius.smBorder,
                                          ),
                                          child: Text(
                                            '+$remaining',
                                            style: theme.textTheme.labelSmall,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                                loading: () => const SizedBox.shrink(),
                                error: (_, _) => const SizedBox.shrink(),
                              ),
                            ],
                            SizedBox(height: dims.noteCardFooterGap),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Bounds the row so the reminder chip can ellipsize.
                                Expanded(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (note.sharedBy != null) ...[
                                        Tooltip(
                                          message:
                                              'Shared by ${note.sharedBy!.name}',
                                          child: _SharedByAvatar(
                                            sharedBy: note.sharedBy!,
                                            serverUrl: serverUrl,
                                            size: 20,
                                          ),
                                        ),
                                        SizedBox(width: dims.xs),
                                      ],
                                      if (note.isOwner && note.hasShares) ...[
                                        _SharedByMeIndicator(
                                          count: note.shareIds!.length,
                                          onTap: isSelectionMode
                                              ? null
                                              : () => AppBottomSheet.show(
                                                  context,
                                                  builder: (_) =>
                                                      ShareNoteSheet(
                                                        noteId: note.id,
                                                      ),
                                                ),
                                        ),
                                        SizedBox(width: dims.xs),
                                      ],
                                      if (note.reminder != null) ...[
                                        Flexible(
                                          child: ReminderChip(
                                            reminder: note.reminder!,
                                            compact: true,
                                          ),
                                        ),
                                        SizedBox(width: dims.xs),
                                      ],
                                      if (note.updatedAt != null)
                                        Flexible(
                                          child: Text(
                                            cardDateLabel(
                                              note.updatedAt!,
                                              prefix: datePrefix,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(
                                                        alpha: AppOpacity
                                                            .secondary,
                                                      ),
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (trailingActions != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: trailingActions!,
                                  ),
                                if (trailingActions == null && !note.isSynced)
                                  Icon(
                                    LucideIcons.cloudOff,
                                    size: AppIconSizes.sm,
                                    color: theme.colorScheme.onSurface
                                        .withValues(
                                          alpha: AppOpacity.secondary,
                                        ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// In place of a locked note's text.
class _LockedLine extends StatelessWidget {
  const _LockedLine();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withValues(
      alpha: AppOpacity.secondary,
    );
    return Row(
      key: const ValueKey('card-locked'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.lock, size: AppIconSizes.sm, color: color),
        SizedBox(width: context.dims.xs),
        Text(
          'Locked',
          style: theme.textTheme.bodyMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _SelectionBadge extends StatelessWidget {
  final bool isSelected;
  const _SelectionBadge({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? theme.colorScheme.primary : Colors.black26,
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : Colors.white.withValues(alpha: 0.8),
          width: 2,
        ),
      ),
      child: isSelected
          ? Icon(
              LucideIcons.check,
              size: AppIconSizes.xs,
              color: theme.colorScheme.onPrimary,
            )
          : null,
    );
  }
}

class _PinBadge extends StatelessWidget {
  const _PinBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: AppRadius.lgBorder,
      ),
      child: const Icon(LucideIcons.pin, size: 13, color: Colors.white),
    );
  }
}

/// Full-bleed image block at the top of a note card.
class _NoteImagePreviews extends StatelessWidget {
  final List<NoteImagePreview> previews;

  /// Opens a picture full size; null leaves taps to the card.
  final ValueChanged<String>? onOpen;

  /// Lo-fi shows pictures in grey.
  final bool grayscale;

  const _NoteImagePreviews({
    required this.previews,
    this.onOpen,
    this.grayscale = false,
  });

  Widget _thumb(int i) {
    final preview = previews[i];
    final Widget thumb = grayscale
        ? ColorFiltered(
            colorFilter: grayscaleFilter,
            child: _Thumb(
              key: ValueKey(preview.attachmentId),
              preview: preview,
            ),
          )
        : _Thumb(key: ValueKey(preview.attachmentId), preview: preview);
    if (onOpen == null) return thumb;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onOpen!(preview.attachmentId),
      child: thumb,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (previews.isEmpty) return const SizedBox.shrink();

    final count = previews.length;

    if (count == 1) {
      return AspectRatio(aspectRatio: _singleImageAspect, child: _thumb(0));
    }

    if (count == 2) {
      return AspectRatio(
        aspectRatio: 2,
        child: Row(
          children: [
            Expanded(child: _thumb(0)),
            const SizedBox(width: 3),
            Expanded(child: _thumb(1)),
          ],
        ),
      );
    }

    if (count == 3) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Row(
          children: [
            Expanded(flex: 2, child: _thumb(0)),
            const SizedBox(width: 3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _thumb(1)),
                  const SizedBox(height: 3),
                  Expanded(child: _thumb(2)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 4-up grid
    return AspectRatio(
      aspectRatio: 1,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _thumb(0)),
                const SizedBox(width: 3),
                Expanded(child: _thumb(1)),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _thumb(2)),
                const SizedBox(width: 3),
                Expanded(child: _thumb(3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single thumbnail tile that downloads the image on demand if not cached locally.
class _Thumb extends ConsumerStatefulWidget {
  final NoteImagePreview preview;

  const _Thumb({super.key, required this.preview});

  @override
  ConsumerState<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends ConsumerState<_Thumb> {
  String? _resolvedPath;
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _Thumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the local path appeared (e.g. after sync downloaded the file), use it
    if (widget.preview.localPath != null &&
        widget.preview.localPath != oldWidget.preview.localPath) {
      setState(() {
        _resolvedPath = widget.preview.localPath;
        _error = false;
      });
    }
  }

  Future<void> _resolveImage() async {
    final localPath = widget.preview.localPath;
    if (localPath != null) {
      final file = File(localPath);
      if (file.existsSync() && file.lengthSync() > 0) {
        if (mounted) setState(() => _resolvedPath = localPath);
        return;
      }
    }

    // Download from server
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final repo = ref.read(noteAttachmentsRepositoryProvider);
      final path = await repo.downloadAttachment(
        widget.preview.noteId,
        widget.preview.attachmentId,
        widget.preview.filename,
      );
      if (mounted) setState(() => _resolvedPath = path);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen<AsyncValue<List<ConnectivityResult>>>(
      connectivityStreamProvider,
      (previous, next) {
        next.whenData((results) {
          if (isOnlineFromResults(results) && _error && mounted) {
            _resolveImage();
          }
        });
      },
    );

    if (_resolvedPath != null && File(_resolvedPath!).existsSync()) {
      return Image.file(
        File(_resolvedPath!),
        fit: BoxFit.cover,
        cacheWidth: 300,
        errorBuilder: (_, _, _) => _placeholder(theme),
      );
    }

    if (_loading) {
      return const ImageShimmer();
    }

    if (_error) {
      return _placeholder(theme);
    }

    return _placeholder(theme);
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Center(
        child: Icon(
          LucideIcons.image,
          size: AppIconSizes.md,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

/// Indicator shown on notes the current user owns and has shared with others.
/// Displays a people icon with the collaborator count and opens the share
/// sheet when tapped.
class _SharedByMeIndicator extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const _SharedByMeIndicator({required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dims = context.dims;
    return Tooltip(
      message: 'Shared with $count ${count == 1 ? 'person' : 'people'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.xsBorder,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: dims.xxs, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.users,
                size: AppIconSizes.xs,
                color: theme.colorScheme.onSurface.withValues(
                  alpha: AppOpacity.secondary,
                ),
              ),
              SizedBox(width: dims.xxs),
              Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: AppOpacity.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar widget to display the profile image of the user who shared the note
class _SharedByAvatar extends StatelessWidget {
  final SharedByUser sharedBy;
  final String? serverUrl;
  final double size;

  const _SharedByAvatar({
    required this.sharedBy,
    this.serverUrl,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileImage = sharedBy.profileImage;

    if (profileImage != null && profileImage.isNotEmpty) {
      String imageUrl = profileImage;
      if (!imageUrl.startsWith('http') && serverUrl != null) {
        imageUrl = '$serverUrl$imageUrl';
      }
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildFallbackAvatar(theme),
          errorWidget: (context, url, error) => _buildFallbackAvatar(theme),
        ),
      );
    }
    return _buildFallbackAvatar(theme);
  }

  Widget _buildFallbackAvatar(ThemeData theme) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          sharedBy.name.isNotEmpty ? sharedBy.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.5,
          ),
        ),
      ),
    );
  }
}

/// A picked card's tint, over it but letting taps through.
class _PickedTint extends StatelessWidget {
  const _PickedTint({
    required this.isSelected,
    required this.color,
    required this.child,
  });

  final bool isSelected;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Always a stack, so picking a card doesn't rebuild what's in it.
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: isSelected
                  ? color.withValues(alpha: 0.14)
                  : Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }
}
