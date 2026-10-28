import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/motion/haptics.dart';
import '../../../core/motion/springs.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/widgets/anchor_sheet.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/notice.dart';
import '../../../core/widgets/pill.dart';
import '../../../core/widgets/shimmer.dart';
import '../../../l10n/l10n.dart';
import '../../notes/domain/note.dart';
import '../../notes/domain/note_dates.dart';
import '../../notes/presentation/widgets/attachment_tile.dart';
import '../../notes/presentation/widgets/note_surface.dart';
import '../../notes/presentation/widgets/title_input_formatter.dart';
import '../../tags/domain/tag.dart';
import '../../tags/presentation/tag_colors.dart';
import '../data/share_sheet_channel.dart';
import '../domain/share_context.dart';

typedef ShareDraft = ({
  String title,
  String text,
  String? link,
  List<String> tagIds,
  List<SharedFile> files,
});

class ShareSheet extends StatefulWidget {
  const ShareSheet({
    super.key,
    required this.intake,
    required this.shareContext,
    required this.onSave,
    required this.onOpenApp,
  });

  final SharedIntake intake;
  final ShareContext shareContext;
  final Future<void> Function(ShareDraft draft) onSave;
  final VoidCallback onOpenApp;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  late final _title = TextEditingController(text: widget.intake.title);
  late final _text = TextEditingController(text: widget.intake.text);
  final Set<String> _tagIds = {};
  final Set<String> _removed = {};
  bool _isSaving = false;

  SharedIntake get _intake => widget.intake;

  List<SharedFile> get _files => [
    for (final file in _intake.files)
      if (!_removed.contains(file.id)) file,
  ];

  bool get _wasNothingShared =>
      !hasTitleText(_intake.title) &&
      _intake.text.trim().isEmpty &&
      _intake.link == null &&
      _intake.files.isEmpty;

  bool get _hasContent =>
      hasTitleText(_title.text) ||
      _text.text.trim().isNotEmpty ||
      _intake.link != null ||
      _files.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _intake.addListener(_changed);
    _title.addListener(_changed);
    _text.addListener(_changed);
  }

  @override
  void dispose() {
    _intake.removeListener(_changed);
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  Future<void> _save() async {
    setState(() => _isSaving = true);
    while (_intake.isCopying) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    await widget.onSave((
      title: _title.text,
      text: _text.text,
      link: _intake.link,
      tagIds: [
        for (final tag in widget.shareContext.tags)
          if (_tagIds.contains(tag.id)) tag.id,
      ],
      files: _files,
    ));
    Haptics.success();
    if (mounted) Navigator.of(context).pop(true);
  }

  String? _skippedMessage(AppLocalizations l10n) {
    final skipped = _intake.skipped;
    final count = skipped.values.fold(0, (sum, count) => sum + count);
    if (count == 0) return null;
    if (skipped.length > 1) return l10n.shareNotAdded(count);
    return switch (skipped.keys.single) {
      SkipReason.unsupported => l10n.shareUnsupported(count),
      SkipReason.tooBig => l10n.shareTooBig(count),
      SkipReason.overLimit => l10n.shareOverLimit,
      SkipReason.unreadable => l10n.shareNotAdded(count),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final density = context.density;
    final isSignedIn = widget.shareContext.userId != null;
    final skipped = _skippedMessage(l10n);
    void close() => Navigator.of(context).pop(false);

    final List<Widget> body;
    final List<Widget> actions;
    if (!isSignedIn) {
      body = [_padded(Notice(text: l10n.shareSignIn))];
      actions = [
        AppButton(
          label: l10n.commonCancel,
          kind: AppButtonKind.secondary,
          onPressed: close,
        ),
        AppButton(label: l10n.shareOpenApp, onPressed: widget.onOpenApp),
      ];
    } else if (_wasNothingShared) {
      body = [
        _padded(
          Notice(kind: NoticeKind.warn, text: skipped ?? l10n.shareNothing),
        ),
      ];
      actions = [AppButton(label: l10n.commonClose, onPressed: close)];
    } else {
      final tags = widget.shareContext.tags;
      body = [
        _padded(
          _DraftCard(
            title: _title,
            text: _text,
            link: _intake.link,
            files: _files,
            staging: _intake.staging,
            onRemove: (file) => setState(() => _removed.add(file.id)),
          ),
        ),
        if (tags.isNotEmpty)
          _TagChoices(
            tags: tags,
            selected: _tagIds,
            onToggle: (tag) => setState(() {
              if (!_tagIds.remove(tag.id)) _tagIds.add(tag.id);
            }),
          ),
        if (skipped != null)
          _padded(Notice(kind: NoticeKind.warn, text: skipped)),
      ];
      actions = [
        AppButton(
          label: l10n.commonCancel,
          kind: AppButtonKind.secondary,
          onPressed: _isSaving ? null : close,
        ),
        AppButton(
          label: l10n.commonSave,
          isBusy: _isSaving,
          onPressed: _hasContent && !_isSaving ? _save : null,
        ),
      ];
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: l10n.shareSheetTitle),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: density.space16,
              children: body,
            ),
          ),
        ),
        SheetFooter(children: actions),
      ],
    );
  }

  Widget _padded(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: child,
  );
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.title,
    required this.text,
    required this.link,
    required this.files,
    required this.staging,
    required this.onRemove,
  });

  final TextEditingController title;
  final TextEditingController text;
  final String? link;
  final List<SharedFile> files;
  final String staging;
  final ValueChanged<SharedFile> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final l10n = context.l10n;
    final appearance = NoteAppearance.of(context, null);
    final radius = BorderRadius.circular(AnchorTokens.radiusCard);
    final hint = TextStyle(color: appearance.colors.muted);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appearance.colors.bg,
        borderRadius: radius,
        border: Border.all(color: appearance.colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AnchorTokens.space8,
          children: [
            TextField(
              controller: title,
              style: AppTypography.navTitle.copyWith(color: colors.appText),
              decoration: InputDecoration.collapsed(
                hintText: l10n.noteTitleHint,
                hintStyle: hint,
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                TitleInputFormatter(
                  onEnter: () => FocusScope.of(context).nextFocus(),
                ),
              ],
            ),
            TextField(
              controller: text,
              style: AppTypography.row.copyWith(color: colors.appText),
              decoration: InputDecoration.collapsed(
                hintText: l10n.editorPlaceholder,
                hintStyle: hint,
              ),
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: 8,
            ),
            if (link case final link?) ...[
              const SizedBox(height: AnchorTokens.space4),
              _LinkRow(link: link, appearance: appearance),
            ],
            if (files.isNotEmpty) ...[
              const SizedBox(height: AnchorTokens.space4),
              SizedBox(
                height: AttachmentTile.height,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: files.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AnchorTokens.space8),
                  itemBuilder: (context, i) => _FileTile(
                    key: ValueKey(files[i].id),
                    file: files[i],
                    staging: staging,
                    appearance: appearance,
                    onRemove: () => onRemove(files[i]),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link, required this.appearance});

  final String link;
  final NoteAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final host = Uri.tryParse(link)?.host.replaceFirst(RegExp('^www\\.'), '');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appearance.colors.surface,
        borderRadius: BorderRadius.circular(AnchorTokens.radiusTile),
        border: Border.all(
          color: appearance.colors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        spacing: 12,
        children: [
          Icon(
            LucideIcons.link,
            size: AnchorTokens.sizeIconMedium,
            color: appearance.colors.muted,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (host != null && host.isNotEmpty)
                  Text(
                    host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.secondary.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.appText,
                    ),
                  ),
                Text(
                  link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.footnote.copyWith(
                    color: appearance.colors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    super.key,
    required this.file,
    required this.staging,
    required this.appearance,
    required this.onRemove,
  });

  final SharedFile file;
  final String staging;
  final NoteAppearance appearance;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final radius = BorderRadius.circular(AnchorTokens.radiusTile);
    final isPicture = file.kind == SharedFileKind.picture;
    final staged = file.file;
    final Widget body;
    if (!file.isReady || staged == null) {
      body = Shimmer(color: appearance.colors.border.withValues(alpha: 0.6));
    } else if (isPicture) {
      body = Image.file(
        File('$staging/$staged'),
        fit: BoxFit.cover,
        cacheWidth: 320,
        frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
          opacity: frame == null && !sync ? 0 : 1,
          duration: context.motion(AnchorTokens.motionDurationFade),
          child: child,
        ),
        errorBuilder: (_, _, _) => const SizedBox.expand(),
      );
    } else {
      body = _AudioTile(file: file, appearance: appearance);
    }
    return AttachmentTile(
      width: isPicture
          ? AttachmentTile.height
          : 210, // off-scale: an audio tile, as in a note
      appearance: appearance,
      deleteLabel: context.l10n.shareRemoveItem(file.name),
      onDelete: () {
        Haptics.selection();
        onRemove();
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: colors.appText.withValues(alpha: 0.08)),
        ),
        decoration: BoxDecoration(
          color: appearance.colors.surface,
          borderRadius: radius,
        ),
        child: body,
      ),
    );
  }
}

class _AudioTile extends StatelessWidget {
  const _AudioTile({required this.file, required this.appearance});

  final SharedFile file;
  final NoteAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final dot = file.name.lastIndexOf('.');
    final name = dot > 0 ? file.name.substring(0, dot) : file.name;
    final duration = file.duration;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            LucideIcons.audioLines,
            size: AnchorTokens.sizeIconMedium,
            color: appearance.colors.muted,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.secondary.copyWith(
                  fontWeight: AnchorTokens.fontWeightMedium,
                  color: colors.appText,
                ),
              ),
              if (duration != null)
                Text(
                  durationLabel(duration),
                  style: AppTypography.footnote.tabular.copyWith(
                    color: appearance.colors.muted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TagChoices extends StatelessWidget {
  const _TagChoices({
    required this.tags,
    required this.selected,
    required this.onToggle,
  });

  final List<Tag> tags;
  final Set<String> selected;
  final ValueChanged<Tag> onToggle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: AnchorTokens.space8,
        children: [
          for (final tag in tags)
            PillButton(
              label: tag.name,
              icon: LucideIcons.hash,
              iconColor: tagColorsOf(context, tag.color).hash,
              isOn: selected.contains(tag.id),
              semanticLabel: context.l10n.shareTag(tag.name),
              onPressed: () {
                Haptics.selection();
                onToggle(tag);
              },
            ),
        ],
      ),
    );
  }
}
