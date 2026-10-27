import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/custom_theme.dart';
import '../../../core/theme/tokens/app_opacity.dart';
import '../../../core/theme/tokens/app_style.dart';
import '../../../core/widgets/app_snackbar.dart';
import 'controllers/theme_preferences_controller.dart';

/// Settings › Custom theme: colours pasted as JSON, kept on this device, over
/// the chosen colour scheme. The same JSON works on the web.
class CustomThemeEditor extends ConsumerStatefulWidget {
  const CustomThemeEditor({super.key});

  @override
  ConsumerState<CustomThemeEditor> createState() => _CustomThemeEditorState();
}

class _CustomThemeEditorState extends ConsumerState<CustomThemeEditor> {
  late final TextEditingController _text;
  List<String> _errors = const [];

  @override
  void initState() {
    super.initState();
    final theme = ref.read(customThemeControllerProvider);
    _text = TextEditingController(
      text: theme == null
          ? ''
          : const JsonEncoder.withIndent('  ').convert(theme.toJson()),
    );
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final errors = await ref
        .read(customThemeControllerProvider.notifier)
        .apply(_text.text);
    if (!mounted) return;
    setState(() => _errors = errors);
    if (errors.isEmpty) {
      final name = ref.read(customThemeControllerProvider)?.name;
      AppSnackbar.showSuccess(
        context,
        message: name == null
            ? 'Custom theme applied'
            : 'Custom theme “$name” applied',
      );
    }
  }

  Future<void> _reset() async {
    _text.clear();
    setState(() => _errors = const []);
    await ref.read(customThemeControllerProvider.notifier).reset();
  }

  Future<void> _copy() async {
    final schemeId = ref.read(colorSchemeControllerProvider);
    final json = themeAsJson(
      schemeById(schemeId) ?? anchorScheme,
      ref.read(customThemeControllerProvider),
    );
    _text.text = json;
    setState(() => _errors = const []);
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      AppSnackbar.showSuccess(context, message: 'Current theme copied as JSON');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    final custom = ref.watch(customThemeControllerProvider);
    final lofi = ref.watch(appStyleControllerProvider) == AppStyle.lofi;
    final muted = theme.colorScheme.onSurface.withValues(
      alpha: AppOpacity.secondary,
    );
    final error = theme.colorScheme.error;

    return Padding(
      padding: EdgeInsets.all(dims.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paste a theme as JSON: colours for light, dark or both. Anything '
            'left out keeps the colour scheme’s colour. Kept on this device; '
            'the same JSON works on the web.'
            '${custom == null
                ? ''
                : lofi
                ? ' Lo-fi draws in its own greys, so the custom theme waits for another style.'
                : ' Applied${custom.name == null ? '' : ': ${custom.name}'}.'}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          SizedBox(height: dims.sm),
          TextField(
            key: const Key('custom-theme-json'),
            controller: _text,
            minLines: 6,
            maxLines: 14,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.multiline,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText:
                  '{\n  "name": "My theme",\n  "dark": { "background": "#000000" }\n}',
              errorText: _errors.isEmpty ? null : '',
              errorStyle: const TextStyle(height: 0, fontSize: 0),
            ),
          ),
          if (_errors.isNotEmpty) ...[
            SizedBox(height: dims.sm),
            for (final message in _errors)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 6),
                      child: Icon(
                        LucideIcons.alertCircle,
                        size: 14,
                        color: error,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          SizedBox(height: dims.sm),
          Wrap(
            spacing: dims.sm,
            runSpacing: dims.sm,
            children: [
              FilledButton(
                onPressed: _text.text.trim().isEmpty ? null : _apply,
                child: const Text('Apply'),
              ),
              OutlinedButton(
                onPressed: custom == null ? null : _reset,
                child: const Text('Reset'),
              ),
              TextButton.icon(
                onPressed: _copy,
                icon: const Icon(LucideIcons.copy, size: 16),
                label: const Text('Copy current theme as JSON'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
