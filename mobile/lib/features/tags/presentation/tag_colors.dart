import 'package:flutter/widgets.dart';

import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../domain/tag.dart';

String tagPaletteOf(String? stored) {
  final color = parseTagColor(
    stored,
    fallback: AnchorTokens.tagStored['blueGrey']!,
  );
  for (final entry in AnchorTokens.tagStored.entries) {
    if (entry.value.toARGB32() == color.toARGB32()) return entry.key;
  }
  return 'blueGrey';
}

AnchorTagColors tagColorsOf(BuildContext context, String? stored) =>
    context.anchor.tags[tagPaletteOf(stored)]!;
