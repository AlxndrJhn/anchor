import 'package:flutter/material.dart';

import '../theme/context_extensions.dart';
import 'anchor_sheet.dart';
import 'grouped_list.dart';

class SheetChoice<T> {
  const SheetChoice({
    required this.value,
    required this.icon,
    required this.label,
    this.subtitle,
    this.detail,
    this.showChevron = false,
    this.isDanger = false,
    this.enabled = true,
  });

  final T value;
  final IconData icon;
  final String label;
  final String? subtitle;

  final String? detail;

  final bool showChevron;
  final bool isDanger;
  final bool enabled;
}

/// A null in [choices] starts a new group.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required List<SheetChoice<T>?> choices,
  String? title,
  String? subtitle,
  String? semanticLabel,
}) {
  final groups = <List<SheetChoice<T>>>[[]];
  for (final choice in choices) {
    if (choice == null) {
      groups.add([]);
    } else {
      groups.last.add(choice);
    }
  }
  return showAnchorSheet<T>(
    context,
    semanticLabel: semanticLabel ?? title,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          SheetHeader(title: title, subtitle: subtitle)
        else
          SizedBox(height: sheet.density.space8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: sheet.density.space16,
            children: [
              for (final group in groups)
                if (group.isNotEmpty)
                  GroupedList(
                    children: [
                      for (final choice in group)
                        GroupedListTile(
                          icon: choice.icon,
                          label: choice.label,
                          subtitle: choice.subtitle,
                          value: choice.detail,
                          showChevron: choice.showChevron,
                          isDanger: choice.isDanger,
                          enabled: choice.enabled,
                          onTap: () => Navigator.of(sheet).pop(choice.value),
                        ),
                    ],
                  ),
            ],
          ),
        ),
        const SheetBottomSpace(),
      ],
    ),
  );
}
