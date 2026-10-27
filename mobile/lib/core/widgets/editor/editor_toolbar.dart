import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'checklist_lines.dart';
import 'color_picker_sheet.dart';
import 'format_palette_sheet.dart';
import 'text_formats.dart';
import 'link_utils.dart';
import '../../theme/context_extensions.dart';
import '../../theme/tokens/app_durations.dart';
import '../../theme/tokens/app_icon_sizes.dart';
import '../../theme/tokens/app_radius.dart';

/// Formatting state for the editor toolbar
class EditorFormattingState {
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrikethrough;
  final bool isBulletList;
  final bool isNumberedList;
  final bool isChecklist;
  final bool isQuote;
  final bool isCode;
  final int headerLevel;
  final int indentLevel;
  final bool canUndo;
  final bool canRedo;
  final String? linkUrl;
  final int linkStart;
  final int linkLength;

  /// The selection's `highlight`, `color` and `font` values, if any.
  final String? highlight;
  final String? textColor;
  final String? font;

  const EditorFormattingState({
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.isBulletList = false,
    this.isNumberedList = false,
    this.isChecklist = false,
    this.isQuote = false,
    this.isCode = false,
    this.headerLevel = 0,
    this.indentLevel = 0,
    this.canUndo = false,
    this.canRedo = false,
    this.linkUrl,
    this.linkStart = 0,
    this.linkLength = 0,
    this.highlight,
    this.textColor,
    this.font,
  });

  bool get isList => isBulletList || isNumberedList || isChecklist;

  /// Buttons show the cheap bound check; the tap handler applies the exact
  /// one-level-below-the-line-above rule.
  bool get canIndent => isList && indentLevel < maxListIndent;
  bool get canOutdent => isList && indentLevel > 0;

  /// Create formatting state from QuillController
  factory EditorFormattingState.fromController(QuillController controller) {
    final style = controller.getSelectionStyle();
    final listValue = style.attributes[Attribute.list.key]?.value;
    final header = style.attributes[Attribute.header.key];
    // linkAtSelection walks the whole document.
    final link = style.attributes.containsKey(Attribute.link.key)
        ? linkAtSelection(controller)
        : null;

    return EditorFormattingState(
      isBold: style.attributes.containsKey(Attribute.bold.key),
      isItalic: style.attributes.containsKey(Attribute.italic.key),
      isUnderline: style.attributes.containsKey(Attribute.underline.key),
      isStrikethrough: style.attributes.containsKey(
        Attribute.strikeThrough.key,
      ),
      isBulletList: listValue == 'bullet',
      isNumberedList: listValue == 'ordered',
      isChecklist: listValue == 'checked' || listValue == 'unchecked',
      isQuote: style.attributes.containsKey(Attribute.blockQuote.key),
      isCode: style.attributes.containsKey(Attribute.codeBlock.key),
      headerLevel: header?.value is int ? header!.value as int : 0,
      indentLevel: style.attributes[Attribute.indent.key]?.value as int? ?? 0,
      canUndo: controller.hasUndo,
      canRedo: controller.hasRedo,
      linkUrl: link?.url,
      linkStart: link?.start ?? 0,
      linkLength: link?.length ?? 0,
      highlight: _stringValue(style, TextFormats.highlightKey),
      textColor: _stringValue(style, TextFormats.colorKey),
      font: _stringValue(style, TextFormats.fontKey),
    );
  }

  static String? _stringValue(Style style, String key) {
    final value = style.attributes[key]?.value;
    return value is String ? value : null;
  }
}

/// The highlight last applied from the toolbar, which the highlighter button
/// reapplies in one tap. Shared by every editor for the app's lifetime.
final lastHighlight = ValueNotifier<String>(highlightPresets.first.name);

/// Custom toolbar for the rich text editor
class EditorToolbar extends StatelessWidget {
  final QuillController controller;
  final EditorFormattingState state;
  final VoidCallback? onLinkPressed;

  const EditorToolbar({
    super.key,
    required this.controller,
    required this.state,
    this.onLinkPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: dims.sm,
        right: dims.sm,
        top: dims.xs,
        bottom: bottomPadding > 0 ? bottomPadding + 4 : 12,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.95)
            : theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Undo/Redo
            _ToolbarGroup(
              buttons: [
                _ToolbarButtonData(
                  icon: LucideIcons.undo2,
                  isEnabled: state.canUndo,
                  onTap: () {
                    controller.undo();
                    HapticFeedback.lightImpact();
                  },
                  tooltip: 'Undo',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.redo2,
                  isEnabled: state.canRedo,
                  onTap: () {
                    controller.redo();
                    HapticFeedback.lightImpact();
                  },
                  tooltip: 'Redo',
                ),
              ],
            ),
            _buildDivider(context, theme),

            // Text styles
            _ToolbarGroup(
              buttons: [
                _ToolbarButtonData(
                  icon: LucideIcons.bold,
                  isActive: state.isBold,
                  onTap: () => _toggleFormat(Attribute.bold),
                  tooltip: 'Bold',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.italic,
                  isActive: state.isItalic,
                  onTap: () => _toggleFormat(Attribute.italic),
                  tooltip: 'Italic',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.underline,
                  isActive: state.isUnderline,
                  onTap: () => _toggleFormat(Attribute.underline),
                  tooltip: 'Underline',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.strikethrough,
                  isActive: state.isStrikethrough,
                  onTap: () => _toggleFormat(Attribute.strikeThrough),
                  tooltip: 'Strikethrough',
                ),
              ],
            ),
            _buildDivider(context, theme),

            // Highlight, text colour and font
            _ToolbarGroup(
              buttons: [
                _ToolbarButtonData(
                  icon: LucideIcons.highlighter,
                  isActive: state.highlight != null,
                  indicatorColor: highlightFill(
                    state.highlight ?? lastHighlight.value,
                  ),
                  onTap: _toggleHighlight,
                  tooltip: state.highlight != null
                      ? 'Remove highlight'
                      : 'Highlight',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.chevronDown,
                  width: 22,
                  iconSize: AppIconSizes.xs,
                  onTap: () => _pickHighlight(context),
                  tooltip: 'Highlight colour',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.baseline,
                  isActive: state.textColor != null,
                  indicatorColor:
                      textColorValue(state.textColor) ??
                      theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  onTap: () => _pickTextColor(context),
                  tooltip: 'Text colour',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.type,
                  isActive: state.font != null,
                  onTap: () => _pickFont(context),
                  tooltip: 'Font',
                ),
              ],
            ),
            _buildDivider(context, theme),

            // Headers
            _ToolbarGroup(
              buttons: [
                _ToolbarButtonData(
                  icon: LucideIcons.heading1,
                  isActive: state.headerLevel == 1,
                  onTap: () => _toggleHeader(1),
                  tooltip: 'Heading 1',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.heading2,
                  isActive: state.headerLevel == 2,
                  onTap: () => _toggleHeader(2),
                  tooltip: 'Heading 2',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.heading3,
                  isActive: state.headerLevel == 3,
                  onTap: () => _toggleHeader(3),
                  tooltip: 'Heading 3',
                ),
              ],
            ),
            _buildDivider(context, theme),

            // Lists
            _ToolbarGroup(
              buttons: [
                _ToolbarButtonData(
                  icon: LucideIcons.listChecks,
                  isActive: state.isChecklist,
                  onTap: () => _toggleList(Attribute.unchecked),
                  tooltip: 'Checklist',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.listOrdered,
                  isActive: state.isNumberedList,
                  onTap: () => _toggleList(Attribute.ol),
                  tooltip: 'Numbered List',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.list,
                  isActive: state.isBulletList,
                  onTap: () => _toggleList(Attribute.ul),
                  tooltip: 'Bullet List',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.indentDecrease,
                  isEnabled: state.canOutdent,
                  onTap: () => _changeIndent(increase: false),
                  tooltip: 'Outdent',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.indentIncrease,
                  isEnabled: state.canIndent,
                  onTap: () => _changeIndent(increase: true),
                  tooltip: 'Indent',
                ),
              ],
            ),
            _buildDivider(context, theme),

            // Blocks
            _ToolbarGroup(
              buttons: [
                _ToolbarButtonData(
                  icon: LucideIcons.quote,
                  isActive: state.isQuote,
                  onTap: () => _toggleBlock(Attribute.blockQuote),
                  tooltip: 'Quote',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.code,
                  isActive: state.isCode,
                  onTap: () => _toggleBlock(Attribute.codeBlock),
                  tooltip: 'Code Block',
                ),
                _ToolbarButtonData(
                  icon: LucideIcons.link,
                  isActive: state.linkUrl != null,
                  onTap: onLinkPressed ?? () {},
                  tooltip: state.linkUrl != null ? 'Edit link' : 'Link',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.dims.xs),
      child: Container(
        width: 1,
        height: 24,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.outline.withValues(alpha: 0),
              theme.colorScheme.outline.withValues(alpha: 0.2),
              theme.colorScheme.outline.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleFormat(Attribute attribute) {
    final style = controller.getSelectionStyle();
    final isActive = style.attributes.containsKey(attribute.key);
    controller.formatSelection(
      isActive ? Attribute.clone(attribute, null) : attribute,
    );
  }

  /// The one-tap highlighter: removes the selection's highlight, or paints
  /// it with the last used colour.
  void _toggleHighlight() {
    final current = controller
        .getSelectionStyle()
        .attributes[TextFormats.highlightKey]
        ?.value;
    controller.formatSelection(
      TextFormats.highlight(current != null ? null : lastHighlight.value),
    );
  }

  Future<void> _pickHighlight(BuildContext context) async {
    // The toolbar leaves the tree while a sheet has focus; later sheets
    // open from the navigator.
    final host = Navigator.of(context).context;
    final choice = await FormatPaletteSheet.show(
      host,
      title: 'Highlight',
      icon: LucideIcons.highlighter,
      swatches: [
        for (final p in highlightPresets)
          PaletteSwatch(p.name, p.label, p.color),
      ],
      clearLabel: 'None',
      current: state.highlight,
      asHighlight: true,
    );
    if (choice == null || !host.mounted) return;
    final value = await _resolve(host, choice, 'Custom highlight', () {
      final fill = highlightFill(state.highlight ?? lastHighlight.value);
      return fill == null ? null : colorToHex(fill);
    });
    if (value == null) return;
    final (chosen,) = value;
    if (chosen != null) lastHighlight.value = chosen;
    controller.formatSelection(TextFormats.highlight(chosen));
  }

  Future<void> _pickTextColor(BuildContext context) async {
    final host = Navigator.of(context).context;
    final choice = await FormatPaletteSheet.show(
      host,
      title: 'Text colour',
      icon: LucideIcons.baseline,
      swatches: [
        for (final p in textColorPresets)
          PaletteSwatch(p.hex, p.label, p.color),
      ],
      clearLabel: 'Default',
      current: state.textColor == null ? null : normalizeHex(state.textColor),
    );
    if (choice == null || !host.mounted) return;
    final value = await _resolve(
      host,
      choice,
      'Custom text colour',
      () => normalizeHex(state.textColor) ?? textColorPresets.first.hex,
    );
    if (value == null) return;
    controller.formatSelection(TextFormats.color(value.$1));
  }

  Future<void> _pickFont(BuildContext context) async {
    final host = Navigator.of(context).context;
    final choice = await FontPickerSheet.show(host, current: state.font);
    if (choice == null) return;
    controller.formatSelection(TextFormats.font(choice.$1));
  }

  /// The value a palette [choice] stands for, asking the colour picker for
  /// "Custom…"; wrapped so null (remove) differs from cancelled (no record).
  Future<(String?,)?> _resolve(
    BuildContext host,
    PaletteChoice choice,
    String customTitle,
    String? Function() customStart,
  ) async {
    switch (choice) {
      case PresetChoice(:final value):
        return (value,);
      case ClearChoice():
        return (null,);
      case CustomChoice():
        final hex = await ColorPickerSheet.show(
          host,
          title: customTitle,
          initialHex: customStart(),
        );
        return hex == null ? null : (hex,);
    }
  }

  void _toggleHeader(int level) {
    final style = controller.getSelectionStyle();
    final currentHeader = style.attributes[Attribute.header.key];
    final currentLevel = currentHeader?.value is int
        ? currentHeader!.value as int
        : 0;

    if (currentLevel == level) {
      controller.formatSelection(Attribute.clone(Attribute.header, null));
    } else {
      final headerAttr = switch (level) {
        1 => Attribute.h1,
        2 => Attribute.h2,
        3 => Attribute.h3,
        _ => Attribute.header,
      };
      controller.formatSelection(headerAttr);
    }
  }

  void _toggleList(Attribute attribute) {
    final style = controller.getSelectionStyle();
    final currentList = style.attributes[Attribute.list.key];
    final currentValue = currentList?.value;

    final isChecklist = attribute == Attribute.unchecked;
    final isCurrentlyChecklist =
        currentValue == 'checked' || currentValue == 'unchecked';

    if (isChecklist && isCurrentlyChecklist) {
      controller.formatSelection(Attribute.clone(Attribute.list, null));
    } else if (currentValue == attribute.value) {
      controller.formatSelection(Attribute.clone(Attribute.list, null));
    } else {
      controller.formatSelection(attribute);
    }
  }

  void _toggleBlock(Attribute attribute) {
    final style = controller.getSelectionStyle();
    final isActive = style.attributes.containsKey(attribute.key);
    controller.formatSelection(
      isActive ? Attribute.clone(attribute, null) : attribute,
    );
  }

  void _changeIndent({required bool increase}) {
    final selection = controller.selection;
    if (!selection.isValid) return;
    final delta = buildListIndentDelta(
      parseDocumentLines(controller.document),
      selection.start,
      selection.end,
      increase: increase,
    );
    if (delta == null) return;
    controller.compose(delta, selection, ChangeSource.local);
  }
}

// Private helper classes
class _ToolbarButtonData {
  final IconData icon;
  final bool isActive;
  final bool? isEnabled;
  final VoidCallback onTap;
  final String tooltip;

  /// A colour bar under the icon (the highlight or text colour it applies).
  final Color? indicatorColor;
  final double width;
  final double iconSize;

  const _ToolbarButtonData({
    required this.icon,
    this.isActive = false,
    this.isEnabled,
    required this.onTap,
    required this.tooltip,
    this.indicatorColor,
    this.width = 36,
    this.iconSize = AppIconSizes.md,
  });
}

class _ToolbarGroup extends StatelessWidget {
  final List<_ToolbarButtonData> buttons;

  const _ToolbarGroup({required this.buttons});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.smBorder,
      ),
      padding: EdgeInsets.all(context.dims.xxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: buttons.map((btn) => _ToolbarButton(data: btn)).toList(),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final _ToolbarButtonData data;

  const _ToolbarButton({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = theme.colorScheme.tertiary;
    final inactiveColor = theme.colorScheme.onSurface.withValues(
      alpha: isDark ? 0.7 : 0.6,
    );
    final disabledColor = theme.colorScheme.onSurface.withValues(alpha: 0.2);

    final hasEnabledState = data.isEnabled != null;
    final isEnabled = data.isEnabled ?? true;

    return Tooltip(
      message: data.tooltip,
      child: GestureDetector(
        onTap: isEnabled
            ? () {
                data.onTap();
                HapticFeedback.selectionClick();
              }
            : null,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: Curves.easeOut,
          width: data.width,
          height: 36,
          decoration: BoxDecoration(
            color: hasEnabledState
                ? Colors.transparent
                : (data.isActive
                      ? activeColor.withValues(alpha: isDark ? 0.25 : 0.15)
                      : Colors.transparent),
            borderRadius: AppRadius.xsBorder,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                data.icon,
                size: data.iconSize,
                color: hasEnabledState
                    ? (isEnabled ? inactiveColor : disabledColor)
                    : (data.isActive ? activeColor : inactiveColor),
              ),
              if (data.indicatorColor != null)
                Positioned(
                  bottom: 4,
                  child: Container(
                    key: Key('${data.tooltip}-indicator'),
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: data.indicatorColor,
                      borderRadius: BorderRadius.circular(1.5),
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
