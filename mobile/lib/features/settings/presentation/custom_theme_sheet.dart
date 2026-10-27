import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/motion/haptics.dart';
import '../../../core/motion/springs.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/custom_theme.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/theme/tokens/app_style.dart';
import '../../../core/widgets/anchor_sheet.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/bottom_bar_frame.dart';
import '../../../core/widgets/grouped_list.dart';
import '../../../l10n/l10n.dart';
import 'theme_preferences_controller.dart';

/// Settings › Appearance › Custom theme: colours pasted as JSON, kept on this
/// device, over the chosen colour scheme. The same JSON works on the web.
Future<void> showCustomThemeSheet(BuildContext context) =>
    showAnchorSheet<void>(
      context,
      semanticLabel: context.l10n.settingsCustomTheme,
      canGrow: true,
      builder: (_) => const CustomThemeSheet(),
    );

class CustomThemeSheet extends ConsumerStatefulWidget {
  const CustomThemeSheet({super.key});

  @override
  ConsumerState<CustomThemeSheet> createState() => _CustomThemeSheetState();
}

class _CustomThemeSheetState extends ConsumerState<CustomThemeSheet> {
  late final TextEditingController _text;
  final _focus = FocusNode();
  List<CustomThemeProblem> _problems = const [];

  /// What Copy put in the box, while the box still holds it.
  String? _copied;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: ref.read(customThemeControllerProvider)?.pretty() ?? '',
    );
    _text.addListener(_changed);
    _focus.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final l10n = context.l10n;
    final problems = await ref
        .read(customThemeControllerProvider.notifier)
        .apply(_text.text);
    if (!mounted) return;
    if (problems.isNotEmpty) {
      setState(() => _problems = problems);
      return;
    }
    final name = ref.read(customThemeControllerProvider)?.name;
    final navigator = Navigator.of(context)..pop();
    AppSnackbar.show(
      navigator.context,
      name == null
          ? l10n.customThemeApplied
          : l10n.customThemeAppliedNamed(name),
      kind: SnackbarKind.success,
    );
  }

  Future<void> _reset() async {
    final l10n = context.l10n;
    await ref.read(customThemeControllerProvider.notifier).reset();
    if (!mounted) return;
    final navigator = Navigator.of(context)..pop();
    AppSnackbar.show(navigator.context, l10n.customThemeRemoved);
  }

  Future<void> _copy() async {
    final json = themeAsJson(
      schemeById(ref.read(colorSchemeControllerProvider)) ?? anchorScheme,
      ref.read(customThemeControllerProvider),
    );
    _text.text = json;
    await Clipboard.setData(ClipboardData(text: json));
    Haptics.success();
    // A toast would cover the sheet's buttons; the Copy button says it.
    if (mounted) {
      setState(() {
        _problems = const [];
        _copied = json;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.anchor;
    final density = context.density;
    final custom = ref.watch(customThemeControllerProvider);
    final hasProblems = _problems.isNotEmpty;
    final copied = _copied != null && _copied == _text.text;
    final note = AppTypography.secondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: l10n.settingsCustomTheme, subtitle: custom?.name),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: density.space12,
              children: [
                Text(
                  l10n.customThemeHelp,
                  style: note.copyWith(color: colors.appMuted),
                ),
                AnimatedContainer(
                  duration: context.motion(AnchorTokens.motionDurationHover),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GroupedList.fillOf(context),
                    borderRadius: context.appStyle.corners(
                      AnchorTokens.radius2xl,
                    ),
                    border: hasProblems
                        ? Border.all(color: colors.statusDanger, width: 2)
                        : _focus.hasFocus
                        ? Border.all(color: colors.accentStrong, width: 2)
                        : Border.all(color: GroupedList.fillOf(context)),
                  ),
                  child: Semantics(
                    textField: true,
                    label: l10n.customThemeJsonLabel,
                    child: TextField(
                      key: const Key('custom-theme-json'),
                      controller: _text,
                      focusNode: _focus,
                      minLines: 6,
                      maxLines: 14,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.multiline,
                      style: AppTypography.code.copyWith(color: colors.appText),
                      cursorColor: colors.accentStrong,
                      scrollPadding: const EdgeInsets.all(AnchorTokens.space24)
                          .copyWith(
                            bottom:
                                AnchorTokens.space24 +
                                BottomBarInset.of(context),
                          ),
                      decoration: InputDecoration(
                        hintText:
                            '{\n  "name": "My theme",\n'
                            '  "dark": { "background": "#000000" }\n}',
                        hintStyle: AppTypography.code.copyWith(
                          color: colors.appMuted,
                        ),
                        semanticCounterText: '',
                      ),
                    ),
                  ),
                ),
                if (hasProblems)
                  Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: density.space8,
                      children: [
                        for (final problem in _problems)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8,
                            children: [
                              SizedBox(
                                height: note.fontSize! * note.height!,
                                child: Icon(
                                  LucideIcons.circleAlert,
                                  size: AnchorTokens.sizeIconSmall,
                                  color: colors.statusDanger,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  problem.textIn(l10n),
                                  style: note.copyWith(
                                    color: colors.statusDanger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppButton(
                    label: copied
                        ? l10n.customThemeCopied
                        : l10n.customThemeCopy,
                    icon: copied ? LucideIcons.check : LucideIcons.copy,
                    kind: AppButtonKind.secondary,
                    size: AppButtonSize.small,
                    isExpanded: false,
                    onPressed: _copy,
                  ),
                ),
              ],
            ),
          ),
        ),
        SheetFooter(
          children: [
            if (custom != null)
              AppButton(
                label: l10n.customThemeReset,
                kind: AppButtonKind.dangerText,
                onPressed: _reset,
              )
            else
              AppButton(
                label: l10n.commonCancel,
                kind: AppButtonKind.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            AppButton(
              label: l10n.customThemeApply,
              onPressed: _text.text.trim().isEmpty ? null : _apply,
            ),
          ],
        ),
      ],
    );
  }
}
