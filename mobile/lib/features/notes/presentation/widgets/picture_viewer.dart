import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/files/image_text.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/logging/log_tags.dart';
import '../../../../core/motion/haptics.dart';
import '../../../../core/motion/springs.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/system_bars.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/cap_height_text.dart';
import '../../../../core/widgets/global_rect_of.dart';
import '../../../../core/widgets/page_bar.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../../picture_search/picture_search.dart';
import '../../data/repository/attachment_file_provider.dart';
import '../../data/repository/note_attachments_repository.dart';
import '../../data/repository/notes_repository.dart';
import '../../data/repository/picture_aspect_ratios.dart';
import '../../domain/note_attachment.dart';
import '../editor/append_text.dart';
import '../notes_controller.dart';
import 'image_text_view.dart';

Future<void> showPictureViewer(
  BuildContext context, {
  required String noteId,
  required List<NoteAttachment> pictures,
  required int initial,
  required bool Function(NoteAttachment) canDelete,
  required ValueChanged<NoteAttachment> onDelete,
  ValueChanged<String>? onGrabText,
  ValueChanged<String>? onSearch,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: null,
      transitionDuration: context.motion(AnchorTokens.motionDurationMorph),
      reverseTransitionDuration: context.motion(
        AnchorTokens.motionDurationMorph,
      ),
      pageBuilder: (_, _, _) => _Viewer(
        noteId: noteId,
        pictures: pictures,
        initial: initial,
        canDelete: canDelete,
        onDelete: onDelete,
        canGrabText: canReadImageText,
        onGrabText: onGrabText,
        onSearch: onSearch,
      ),
      transitionsBuilder: (_, animation, _, child) => child,
    ),
  );
}

/// Opens a note's pictures from outside the note (a card's picture),
/// starting at [attachmentId]. Nothing can be deleted from there; text
/// grabbed from a picture goes at the end of the note, when the user may
/// edit it; a detected tag searches the list it was opened from.
Future<void> showNotePictures(
  BuildContext context,
  WidgetRef ref, {
  required String noteId,
  required String attachmentId,
}) async {
  final repo = ref.read(noteAttachmentsRepositoryProvider);
  final pictures = (await repo.watchAttachments(noteId).first)
      .where((attachment) => attachment.isImage)
      .toList();
  final initial = pictures.indexWhere((p) => p.id == attachmentId);
  if (initial < 0 || !context.mounted) return;
  final notes = ref.read(notesRepositoryProvider);
  final note = await notes.getNote(noteId);
  final canAddText = note != null && note.isActive && note.canEdit;
  if (!context.mounted) return;
  Haptics.light();
  await showPictureViewer(
    context,
    noteId: noteId,
    pictures: pictures,
    initial: initial,
    canDelete: (_) => false,
    onDelete: (_) {},
    onGrabText: canAddText
        ? (text) => unawaited(
            notes.changeContent(
              noteId,
              (content) => appendTextContent(content, text),
            ),
          )
        : null,
    onSearch: (word) => ref.read(searchQueryProvider.notifier).set(word),
  );
}

class _Viewer extends ConsumerStatefulWidget {
  const _Viewer({
    required this.noteId,
    required this.pictures,
    required this.initial,
    required this.canDelete,
    required this.onDelete,
    this.canGrabText = false,
    this.onGrabText,
    this.onSearch,
  });

  final String noteId;
  final List<NoteAttachment> pictures;
  final int initial;
  final bool Function(NoteAttachment) canDelete;
  final ValueChanged<NoteAttachment> onDelete;

  /// Whether "Grab image text" is offered: the text in a picture can be read
  /// on this phone.
  final bool canGrabText;

  /// Takes the text picked from a picture into the note; null where the note
  /// can't be edited, which leaves copying it.
  final ValueChanged<String>? onGrabText;

  /// Searches the notes for a tag detected in a picture; once the viewer
  /// has closed. Null offers no detected tags.
  final ValueChanged<String>? onSearch;

  @override
  ConsumerState<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends ConsumerState<_Viewer>
    with TickerProviderStateMixin {
  late final PageController _pages = PageController(
    initialPage: widget.initial,
  );
  late int _index = widget.initial;
  final Map<String, String?> _files = {};

  /// Pictures whose download failed, as opposed to waiting for a connection.
  final Set<String> _failedIds = {};
  final Map<String, TransformationController> _zoom = {};
  bool _isImmersive = false;
  bool _zoomed = false;
  bool _isReadingText = false;

  /// What the picture search model sees in a picture, by attachment id.
  final Map<String, List<PictureLabel>> _tags = {};
  String? _tagsShownFor;
  bool _isFindingTags = false;

  /// The pull down, in pixels.
  late final AnimationController _pull = AnimationController.unbounded(
    vsync: this,
  );
  Offset _drag = Offset.zero;

  NoteAttachment get _current => widget.pictures[_index];

  @override
  void initState() {
    super.initState();
    _fetch(_index);
    if (_index > 0) _fetch(_index - 1);
    if (_index < widget.pictures.length - 1) _fetch(_index + 1);
  }

  @override
  void dispose() {
    _pages.dispose();
    _pull.dispose();
    for (final zoom in _zoom.values) {
      zoom.dispose();
    }
    super.dispose();
  }

  Future<void> _fetch(int i) async {
    final picture = widget.pictures[i];
    if (_files.containsKey(picture.id)) return;
    _files[picture.id] = null;
    try {
      final file = await ref.read(
        attachmentFileProvider(attachmentFileKeyOf(picture)).future,
      );
      if (file != null) {
        await ref.read(pictureAspectRatiosProvider).measure(picture.id, file);
      }
      if (!mounted) return;
      setState(() {
        if (file == null) {
          _files.remove(picture.id);
        } else {
          _files[picture.id] = file;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _files.remove(picture.id);
        _failedIds.add(picture.id);
      });
    }
  }

  void _retry(NoteAttachment picture) {
    ref.invalidate(attachmentFileProvider(attachmentFileKeyOf(picture)));
    setState(() => _failedIds.remove(picture.id));
    _fetch(widget.pictures.indexOf(picture));
  }

  void _fetchMissing() {
    for (var i = _index - 1; i <= _index + 1; i++) {
      if (i < 0 || i >= widget.pictures.length) continue;
      final picture = widget.pictures[i];
      if (_files.containsKey(picture.id)) continue;
      _failedIds.remove(picture.id);
      ref.invalidate(attachmentFileProvider(attachmentFileKeyOf(picture)));
      _fetch(i);
    }
  }

  TransformationController _zoomOf(String id) => _zoom.putIfAbsent(id, () {
    final zoom = TransformationController();
    zoom.addListener(() {
      final zoomed = zoom.value.getMaxScaleOnAxis() > 1.01;
      if (zoomed != _zoomed && mounted) setState(() => _zoomed = zoomed);
    });
    return zoom;
  });

  void _close() => Navigator.of(context).pop();

  void _dragUpdate(DragUpdateDetails details) {
    _drag += details.delta;
    _pull.value = math.max(0, _drag.dy);
    setState(() {});
  }

  void _dragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_pull.value > 120 || velocity > 700) {
      Haptics.light();
      _close();
      return;
    }
    final from = _drag;
    final run = AnimationController(vsync: this);
    run.addListener(() {
      final progress = run.value;
      setState(() {
        _drag = Offset.lerp(from, Offset.zero, progress)!;
        _pull.value = math.max(0, _drag.dy);
      });
    });
    run.springTo(1, spring: Spring.snappy).whenCompleteOrCancel(run.dispose);
  }

  void _doubleTap(TapDownDetails at) {
    final zoom = _zoomOf(_current.id);
    Haptics.selection();
    if (_zoomed) {
      zoom.value = Matrix4.identity();
      return;
    }
    const scale = 2.5;
    final position = at.localPosition;
    zoom.value = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (scale - 1),
        -position.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  Future<void> _share(BuildContext button) async {
    final file = _files[_current.id];
    if (file == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file)],
        sharePositionOrigin: globalRectOf(button),
      ),
    );
  }

  Future<void> _save() async {
    final file = _files[_current.id];
    if (file == null) return;
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        if (mounted) {
          AppSnackbar.show(
            context,
            context.l10n.pictureAllowPhotos,
            kind: SnackbarKind.error,
          );
        }
        return;
      }
      await Gal.putImage(file);
      if (mounted) {
        AppSnackbar.show(
          context,
          context.l10n.pictureSaved,
          kind: SnackbarKind.success,
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(
          context,
          context.l10n.pictureSaveFailed,
          kind: SnackbarKind.error,
        );
      }
    }
  }

  /// Finds the text in the picture and shows it marked on the picture, to
  /// copy some or all of it, or put it in the note.
  Future<void> _grabText() async {
    final file = _files[_current.id];
    if (file == null || _isReadingText) return;
    final l10n = context.l10n;
    setState(() => _isReadingText = true);
    final ImageText found;
    try {
      found = await recognizeImageText(file);
    } catch (error, stack) {
      AppLogger.instance.warn(
        LogTags.notes,
        'Grab image text failed',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        setState(() => _isReadingText = false);
        AppSnackbar.show(
          context,
          l10n.pictureTextFailed,
          kind: SnackbarKind.error,
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isReadingText = false);
    if (found.isEmpty) {
      AppSnackbar.show(context, l10n.pictureNoText, kind: SnackbarKind.info);
      return;
    }
    final onText = widget.onGrabText;
    final inserted = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (page) => ImageTextView(
          image: FileImage(File(file)),
          imageSize: found.imageSize,
          text: found,
          onInsert: onText == null
              ? null
              : (text) => Navigator.of(page).pop(text),
        ),
      ),
    );
    if (inserted == null || onText == null || !mounted) return;
    onText(inserted);
    _close();
    AppSnackbar.show(context, l10n.pictureTextAdded);
  }

  /// Shows or hides the words for what the picture shows, asking the server
  /// the first time.
  Future<void> _toggleTags() async {
    final id = _current.id;
    if (_tagsShownFor == id) {
      setState(() => _tagsShownFor = null);
      return;
    }
    if (_tags.containsKey(id)) {
      setState(() => _tagsShownFor = id);
      return;
    }
    if (_isFindingTags) return;
    final l10n = context.l10n;
    setState(() => _isFindingTags = true);
    final List<PictureLabel> labels;
    try {
      labels = await ref.read(pictureSearchRepositoryProvider).labels(id);
    } catch (error, stack) {
      AppLogger.instance.warn(
        LogTags.notes,
        'Detected tags failed',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        setState(() => _isFindingTags = false);
        AppSnackbar.show(
          context,
          l10n.pictureTagsFailed,
          kind: SnackbarKind.error,
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isFindingTags = false);
    if (labels.isEmpty) {
      AppSnackbar.show(
        context,
        l10n.pictureTagsNotYet,
        kind: SnackbarKind.info,
      );
      return;
    }
    Haptics.selection();
    setState(() {
      _tags[id] = labels;
      if (_current.id == id) _tagsShownFor = id;
    });
  }

  /// A tag in the phone's language: the words come in German and English.
  String _tagText(PictureLabel label) =>
      label.textFor(View.of(context).platformDispatcher.locale.languageCode);

  void _searchFor(String word) {
    Haptics.light();
    _close();
    widget.onSearch?.call(word);
  }

  void _delete() {
    final picture = _current;
    _close();
    widget.onDelete(picture);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(isOnlineProvider, (wasOnline, isOnline) {
      if (isOnline && wasOnline != true) _fetchMissing();
    });
    final isOnline = ref.watch(isOnlineProvider);
    final hasPicture = _files[_current.id] != null;
    final shapes = ref.watch(pictureAspectRatiosProvider);
    final media = MediaQuery.of(context);
    final route = ModalRoute.of(context)!;
    final pulled = (_pull.value / 400).clamp(0.0, 1.0);
    final shrink = 1 - 0.25 * pulled;
    final count = widget.pictures.length;
    const ink = AnchorTokens.colorMediaText;
    final barsShown = !_isImmersive && pulled == 0;
    // Detected tags need picture search on, a connection and an uploaded
    // picture.
    final canShowTags =
        widget.onSearch != null &&
        isOnline &&
        !_current.isPendingUpload &&
        !_current.isUploadFailed &&
        (ref.watch(pictureSearchStatusProvider).value?.enabled ?? false);
    final tags = _tagsShownFor == _current.id ? _tags[_current.id] : null;
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: route.animation!,
        builder: (context, child) {
          final progress = AnchorTokens.motionEaseStandard.transform(
            route.animation!.value,
          );
          return ColoredBox(
            color: Colors.black.withValues(alpha: progress * (1 - pulled)),
            child: child,
          );
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _isImmersive = !_isImmersive),
                onDoubleTapDown: hasPicture ? _doubleTap : null,
                onDoubleTap: hasPicture ? () {} : null,
                onVerticalDragUpdate: _zoomed ? null : _dragUpdate,
                onVerticalDragEnd: _zoomed ? null : _dragEnd,
                child: PageView.builder(
                  controller: _pages,
                  physics: _zoomed || _pull.value > 0
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  itemCount: count,
                  onPageChanged: (i) {
                    Haptics.selection();
                    setState(() => _index = i);
                    _fetch(i);
                    if (i > 0) _fetch(i - 1);
                    if (i < count - 1) _fetch(i + 1);
                  },
                  itemBuilder: (context, i) {
                    final attachment = widget.pictures[i];
                    final file = _files[attachment.id];
                    final shape = shapes.of(attachment.id) ?? 1;
                    final picture = file == null
                        ? Center(
                            child: _files.containsKey(attachment.id)
                                ? const Spinner(
                                    size: AnchorTokens.sizeIconLarge,
                                    color: ink,
                                  )
                                : isOnline && _failedIds.contains(attachment.id)
                                ? _LoadFailed(
                                    name: attachment.originalFilename,
                                    onRetry: () => _retry(attachment),
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: 12,
                                    children: [
                                      const Icon(
                                        LucideIcons.cloudOff,
                                        size:
                                            36, // off-scale: art on the dark viewer
                                        color: AnchorTokens.colorMediaFaint,
                                      ),
                                      Text(
                                        context.l10n.pictureOffline,
                                        style: AppTypography.secondary.copyWith(
                                          color: AnchorTokens.colorMediaMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                          )
                        : InteractiveViewer(
                            transformationController: _zoomOf(attachment.id),
                            minScale: 1,
                            maxScale: 4,
                            panEnabled: _zoomed,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: shape,
                                child: Semantics(
                                  container: true,
                                  image: true,
                                  label: attachment.originalFilename,
                                  child: Hero(
                                    tag: 'picture-${attachment.id}',
                                    child: _Picture(file: file),
                                  ),
                                ),
                              ),
                            ),
                          );
                    if (i != _index) return picture;
                    return Transform.translate(
                      offset: _drag,
                      child: Transform.scale(scale: shrink, child: picture),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _Fade(
                shown: barsShown,
                child: Container(
                  height: media.padding.top + PageBar.heightOf(context),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x8C000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: PageBar(
                isHidden: !barsShown,
                isTitleCentered: true,
                systemBars: systemBarsStyle(dark: true),
                leading: BarButton(
                  icon: LucideIcons.x,
                  label: context.l10n.commonClose,
                  color: ink,
                  onPressed: _close,
                ),
                title: Semantics(
                  liveRegion: true,
                  child: CapHeightText(
                    count > 1
                        ? context.l10n.commonPosition(_index + 1, count)
                        : '',
                    style: AppTypography.secondary.tabular.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ),
              ),
            ),
            if (tags != null)
              Positioned(
                left: 16,
                right: 16,
                // off-scale: just above the buttons' scrim
                bottom: media.padding.bottom + 72,
                child: _Fade(
                  shown: barsShown,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final label in tags)
                        _TagPill(
                          text: _tagText(label),
                          onPressed: widget.onSearch == null
                              ? null
                              : () => _searchFor(_tagText(label)),
                        ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Fade(
                shown: barsShown,
                child: Container(
                  height:
                      media.padding.bottom + 64, // off-scale: buttons' scrim
                  padding: EdgeInsets.only(bottom: media.padding.bottom),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x8C000000)],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Builder(
                        builder: (button) => BarButton(
                          icon: LucideIcons.share,
                          label: context.l10n.actionShare,
                          color: ink,
                          onPressed: () => _share(button),
                        ),
                      ),
                      BarButton(
                        icon: LucideIcons.download,
                        label: context.l10n.pictureSaveToPhotos,
                        color: ink,
                        onPressed: _save,
                      ),
                      if (widget.canGrabText)
                        _isReadingText
                            ? Semantics(
                                label: context.l10n.pictureReadingText,
                                child: const SizedBox.square(
                                  dimension: AnchorTokens.sizeControlMedium,
                                  child: Center(
                                    child: Spinner(
                                      size: AnchorTokens.sizeIconLarge,
                                      color: ink,
                                    ),
                                  ),
                                ),
                              )
                            : BarButton(
                                icon: LucideIcons.scanText,
                                label: context.l10n.pictureGrabText,
                                color: ink,
                                onPressed: hasPicture ? _grabText : null,
                              ),
                      if (canShowTags)
                        _isFindingTags
                            ? Semantics(
                                label: context.l10n.pictureFindingTags,
                                child: const SizedBox.square(
                                  dimension: AnchorTokens.sizeControlMedium,
                                  child: Center(
                                    child: Spinner(
                                      size: AnchorTokens.sizeIconLarge,
                                      color: ink,
                                    ),
                                  ),
                                ),
                              )
                            : BarButton(
                                icon: LucideIcons.tags,
                                label: tags == null
                                    ? context.l10n.pictureShowTags
                                    : context.l10n.pictureHideTags,
                                color: tags == null
                                    ? ink
                                    : AnchorTokens.colorAccentFill,
                                onPressed: hasPicture ? _toggleTags : null,
                              ),
                      if (widget.canDelete(_current))
                        BarButton(
                          icon: LucideIcons.trash2,
                          label: context.l10n.actionDelete,
                          color: const Color(0xFFFF8F85),
                          onPressed: _delete,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A detected tag: tapping it searches the notes for it.
class _TagPill extends StatelessWidget {
  const _TagPill({required this.text, required this.onPressed});

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      style: PressStyle.button,
      onTap: onPressed,
      semanticLabel: context.l10n.pictureSearchTag(text),
      child: Container(
        height: AnchorTokens.sizeControlSmall,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AnchorTokens.colorMediaShadeStrong,
          borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
        ),
        child: ExcludeSemantics(
          child: CapHeightText(
            text,
            style: AppTypography.secondary.copyWith(
              fontWeight: FontWeight.w600,
              color: AnchorTokens.colorMediaText,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.name, required this.onRetry});

  final String name;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        const Icon(
          LucideIcons.circleAlert,
          size: 36, // off-scale: art on the dark viewer
          color: AnchorTokens.colorMediaFaint,
        ),
        Text(
          context.l10n.pictureLoadFailed,
          style: AppTypography.secondary.copyWith(
            color: AnchorTokens.colorMediaMuted,
          ),
        ),
        Pressable(
          style: PressStyle.inverse,
          onTap: onRetry,
          semanticLabel: context.l10n.attachmentRetry(name),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AnchorTokens.sizeControlSmall,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AnchorTokens.colorMediaControl,
              borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                context.l10n.commonTryAgain,
                style: AppTypography.secondary.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AnchorTokens.colorMediaText,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({required this.shown, required this.child});

  final bool shown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !shown,
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: context.motion(AnchorTokens.motionDurationFade),
        child: child,
      ),
    );
  }
}

class _Picture extends StatelessWidget {
  const _Picture({required this.file});

  final String file;

  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context).width *
        MediaQuery.devicePixelRatioOf(context) *
        2;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(file),
          fit: BoxFit.cover,
          cacheWidth: 320,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.expand(),
        ),
        Image.file(
          File(file),
          fit: BoxFit.cover,
          cacheWidth: width.round(),
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
            opacity: frame == null && !sync ? 0 : 1,
            duration: context.motion(AnchorTokens.motionDurationSlow),
            child: child,
          ),
          errorBuilder: (_, _, _) => const SizedBox.expand(),
        ),
      ],
    );
  }
}
