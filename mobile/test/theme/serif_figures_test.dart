import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('serif styles use lining figures', (tester) async {
    final textTheme = AppTheme.light().textTheme;
    final styles = <String, TextStyle?>{
      'serifText': AppTypography.serifText(fontSize: 20),
      'largeTitle': AppTypography.largeTitle,
      'displayLarge': textTheme.displayLarge,
      'displayMedium': textTheme.displayMedium,
    };

    for (final entry in styles.entries) {
      expect(entry.value?.fontFamily, AppTypography.serif);
      expect(
        entry.value?.fontFeatures,
        contains(const FontFeature.liningFigures()),
        reason: '${entry.key} would render "Note 4" with a descending 4',
      );
    }
  });
}
