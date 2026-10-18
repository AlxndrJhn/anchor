import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/features/notes/presentation/widgets/note_chips.dart';
import 'package:anchor/features/notes/presentation/widgets/note_surface.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  testWidgets('the remove button sits snug in the chip and is easy to hit', (
    tester,
  ) async {
    var removed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TagChip(
                tag: const Tag(id: 't1', name: 'family'),
                appearance: NoteAppearance.of(context, null),
                onRemove: () => removed++,
              ),
            ),
          ),
        ),
      ),
    );

    final chip = tester.getRect(find.byType(TagChip));
    final x = tester.getRect(find.byIcon(LucideIcons.x));
    expect(chip.right - x.right, 8, reason: 'as the guide’s .pg-ed .chip .x');
    expect(chip.height, AnchorTokens.sizeControlSmall);

    // Above and left of the icon, still inside the chip.
    await tester.tapAt(Offset(x.left - 6, chip.top + 2));
    expect(removed, 1);
  });
}
