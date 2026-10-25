import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:anchor/core/theme/context_extensions.dart';
import 'package:anchor/core/theme/tokens/app_radius.dart';

/// Search field at the top of the notes list.
class NotesSearchBar extends StatelessWidget {
  const NotesSearchBar({
    super.key,
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
    this.filterCount = 0,
    this.onFilter,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  /// How many filters are on, shown on the filter button.
  final int filterCount;
  final VoidCallback? onFilter;

  /// Tap target of the clear button. Material's default 48 would set the
  /// floor for the whole bar, so this matches a `VisualDensity.compact` one.
  static const double _clearButtonSize = 40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SearchBar(
      controller: controller,
      hintText: 'Search your thoughts...',
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      constraints: BoxConstraints(minHeight: context.dims.searchBarHeight),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
      ),
      leading: const Icon(LucideIcons.search),
      trailing: [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(LucideIcons.x),
            tooltip: 'Clear search',
            onPressed: onClear,
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(_clearButtonSize),
              maximumSize: const Size.square(_clearButtonSize),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        if (onFilter != null)
          IconButton(
            icon: Badge(
              isLabelVisible: filterCount > 0,
              label: Text('$filterCount'),
              backgroundColor: theme.colorScheme.tertiary,
              child: Icon(
                LucideIcons.listFilter,
                color: filterCount > 0 ? theme.colorScheme.tertiary : null,
              ),
            ),
            tooltip: filterCount > 0
                ? 'Filters, $filterCount on'
                : 'Filter notes',
            onPressed: onFilter,
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(_clearButtonSize),
              maximumSize: const Size.square(_clearButtonSize),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
