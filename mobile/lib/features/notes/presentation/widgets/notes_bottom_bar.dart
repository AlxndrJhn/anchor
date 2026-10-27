import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/motion/springs.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/frosted_glass.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';

class NotesBottomBar extends StatefulWidget {
  const NotesBottomBar({
    super.key,
    required this.placeholder,
    required this.compact,
    required this.searching,
    required this.query,
    required this.onStartSearch,
    required this.onQuery,
    required this.onCancel,
    this.onNewNote,
    this.onHoldNewNote,
    this.newNoteKey,
    this.filterCount = 0,
    this.onFilter,
  });

  final String placeholder;
  final bool compact;
  final bool searching;
  final String query;
  final VoidCallback onStartSearch;
  final ValueChanged<String> onQuery;
  final VoidCallback onCancel;

  /// Null hides New note.
  final VoidCallback? onNewNote;

  /// Holding the New note button, for more kinds of new note.
  final VoidCallback? onHoldNewNote;

  final GlobalKey? newNoteKey;

  /// How many filters are on; the filter button shows on while any is.
  final int filterCount;

  /// Null leaves the filter button out of the search field.
  final VoidCallback? onFilter;

  @override
  State<NotesBottomBar> createState() => _NotesBottomBarState();
}

class _NotesBottomBarState extends State<NotesBottomBar> {
  late final TextEditingController _text = TextEditingController(
    text: widget.query,
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(NotesBottomBar old) {
    super.didUpdateWidget(old);
    if (widget.searching && !old.searching) {
      _text.text = widget.query;
      // A search that arrives with its words (a picture's tag) shows the
      // results instead of the keyboard.
      if (widget.query.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _focus.requestFocus(),
        );
      }
    }
    if (!widget.searching && old.searching) {
      _text.clear();
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final control = context.density.control;
    final compact = widget.compact && !widget.searching;
    final duration = context.motion(Spring.snappy.duration);
    final search = Pressable(
      style: PressStyle.button,
      onTap: widget.searching ? null : widget.onStartSearch,
      isButton: !widget.searching,
      semanticLabel: widget.searching ? null : widget.placeholder,
      child: FrostedGlass(
        child: SizedBox(
          height: control,
          child: LayoutBuilder(
            builder: (context, box) {
              final full = _fieldWidth(context);
              final open = full <= control
                  ? 1.0
                  : ((box.maxWidth - control) / (full - control)).clamp(
                      0.0,
                      1.0,
                    );
              return ClipRect(
                child: OverflowBox(
                  alignment: AlignmentDirectional.centerStart,
                  minWidth: full,
                  maxWidth: full,
                  child: Row(
                    children: [
                      SizedBox(
                        width: lerpDouble(
                          (control - AnchorTokens.sizeIconMedium) / 2,
                          16,
                          open,
                        ),
                      ),
                      Icon(
                        LucideIcons.search,
                        size: AnchorTokens.sizeIconMedium,
                        color: colors.appText,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Opacity(
                          opacity: const Interval(0.4, 1).transform(open),
                          child: widget.searching
                              ? TextField(
                                  controller: _text,
                                  focusNode: _focus,
                                  onChanged: widget.onQuery,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => _focus.unfocus(),
                                  style: AppTypography.row.copyWith(
                                    color: colors.appText,
                                  ),
                                  cursorColor: colors.accentStrong,
                                  decoration: InputDecoration(
                                    hintText: widget.placeholder,
                                  ),
                                )
                              : ExcludeSemantics(
                                  child: Text(
                                    widget.placeholder,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.row.copyWith(
                                      color: colors.appMuted,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      if (widget.searching && widget.query.isNotEmpty)
                        BarButton(
                          icon: LucideIcons.circleX,
                          label: context.l10n.searchClear,
                          size: BarButtonSize.medium,
                          color: colors.appMuted,
                          onPressed: () {
                            _text.clear();
                            widget.onQuery('');
                          },
                        ),
                      if (widget.searching && widget.onFilter != null)
                        BarButton(
                          icon: LucideIcons.listFilter,
                          label: widget.filterCount > 0
                              ? context.l10n.searchFiltersOn(widget.filterCount)
                              : context.l10n.searchFilter,
                          size: BarButtonSize.medium,
                          color: widget.filterCount > 0
                              ? colors.appText
                              : colors.appMuted,
                          indicatorColor: widget.filterCount > 0
                              ? colors.accentStrong
                              : null,
                          onPressed: widget.onFilter,
                        )
                      else if (!widget.searching || widget.query.isEmpty)
                        const SizedBox(width: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: AnimatedContainer(
            duration: duration,
            curve: Spring.snappy.curve,
            width: compact ? control : _fieldWidth(context),
            child: search,
          ),
        ),
        if (widget.searching)
          Pressable(
            style: PressStyle.button,
            onTap: widget.onCancel,
            child: FrostedGlass(
              child: Container(
                height: control,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: Center(
                  child: Text(
                    context.l10n.commonCancel,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: AppTypography.row.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.appText,
                    ),
                  ),
                ),
              ),
            ),
          )
        else if (widget.onNewNote != null)
          Pressable(
            style: PressStyle.bottomBar,
            onTap: widget.onNewNote,
            onLongPress: widget.onHoldNewNote,
            semanticLabel: context.l10n.noteNew,
            child: Container(
              key: widget.newNoteKey,
              width: control,
              height: control,
              decoration: BoxDecoration(
                shape: context.appStyle.roundFab
                    ? BoxShape.circle
                    : BoxShape.rectangle,
                borderRadius: context.appStyle.roundFab
                    ? null
                    : context.appStyle.corners(AnchorTokens.radiusFab),
                color: colors.appInverse,
                boxShadow: colors.shadowFab,
              ),
              child: const NewNoteIcon(),
            ),
          ),
      ],
    );
  }

  double _cancelWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: context.l10n.commonCancel,
        style: AppTypography.row.copyWith(fontWeight: FontWeight.w600),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble() + 12 * 2;
    painter.dispose();
    return width;
  }

  double _fieldWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 28;
    if (widget.searching) return width - 10 - _cancelWidth(context);
    if (widget.onNewNote == null) return width;
    return width - 10 - (context.density.control + 6);
  }
}

class NewNoteIcon extends StatelessWidget {
  const NewNoteIcon({super.key});

  @override
  Widget build(BuildContext context) => Icon(
    LucideIcons.penLine,
    size: AnchorTokens.sizeIconLarge,
    color: context.anchor.appOnInverse,
  );
}
