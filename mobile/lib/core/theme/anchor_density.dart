import 'package:flutter/material.dart';

import 'display_density.dart';
import 'tokens/anchor_tokens.dart';

@immutable
class AnchorDensity extends ThemeExtension<AnchorDensity> {
  const AnchorDensity({
    required this.density,
    required this.space8,
    required this.space12,
    required this.space16,
    required this.space24,
    required this.space32,
    required this.space48,
    required this.control,
    required this.bar,
    required this.noteLineHeight,
    required this.previewMasonry,
    required this.previewGrid,
    required this.previewList,
    required this.previewPictures,
  });

  final DisplayDensity density;

  final double space8;
  final double space12;
  final double space16;
  final double space24;
  final double space32;
  final double space48;

  final double control;

  final double bar;

  final double noteLineHeight;

  final int previewMasonry;
  final int previewGrid;
  final int previewList;

  final int previewPictures;

  bool get isCompact => density == DisplayDensity.compact;

  double get largeBar => bar + AnchorTokens.space8;

  static const standard = AnchorDensity(
    density: DisplayDensity.standard,
    space8: AnchorTokens.densityDefaultSpace8,
    space12: AnchorTokens.densityDefaultSpace12,
    space16: AnchorTokens.densityDefaultSpace16,
    space24: AnchorTokens.densityDefaultSpace24,
    space32: AnchorTokens.densityDefaultSpace32,
    space48: AnchorTokens.densityDefaultSpace48,
    control: AnchorTokens.densityDefaultControl,
    bar: AnchorTokens.densityDefaultBar,
    noteLineHeight: AnchorTokens.densityDefaultNoteLineHeight,
    previewMasonry: AnchorTokens.densityDefaultPreviewMasonry,
    previewGrid: AnchorTokens.densityDefaultPreviewGrid,
    previewList: AnchorTokens.densityDefaultPreviewList,
    previewPictures: AnchorTokens.densityDefaultPreviewPictures,
  );

  static const compact = AnchorDensity(
    density: DisplayDensity.compact,
    space8: AnchorTokens.densityCompactSpace8,
    space12: AnchorTokens.densityCompactSpace12,
    space16: AnchorTokens.densityCompactSpace16,
    space24: AnchorTokens.densityCompactSpace24,
    space32: AnchorTokens.densityCompactSpace32,
    space48: AnchorTokens.densityCompactSpace48,
    control: AnchorTokens.densityCompactControl,
    bar: AnchorTokens.densityCompactBar,
    noteLineHeight: AnchorTokens.densityCompactNoteLineHeight,
    previewMasonry: AnchorTokens.densityCompactPreviewMasonry,
    previewGrid: AnchorTokens.densityCompactPreviewGrid,
    previewList: AnchorTokens.densityCompactPreviewList,
    previewPictures: AnchorTokens.densityCompactPreviewPictures,
  );

  static AnchorDensity of(DisplayDensity density) => switch (density) {
    DisplayDensity.standard => standard,
    DisplayDensity.compact => compact,
  };

  @override
  AnchorDensity copyWith({
    DisplayDensity? density,
    double? space8,
    double? space12,
    double? space16,
    double? space24,
    double? space32,
    double? space48,
    double? control,
    double? bar,
    double? noteLineHeight,
    int? previewMasonry,
    int? previewGrid,
    int? previewList,
    int? previewPictures,
  }) => AnchorDensity(
    density: density ?? this.density,
    space8: space8 ?? this.space8,
    space12: space12 ?? this.space12,
    space16: space16 ?? this.space16,
    space24: space24 ?? this.space24,
    space32: space32 ?? this.space32,
    space48: space48 ?? this.space48,
    control: control ?? this.control,
    bar: bar ?? this.bar,
    noteLineHeight: noteLineHeight ?? this.noteLineHeight,
    previewMasonry: previewMasonry ?? this.previewMasonry,
    previewGrid: previewGrid ?? this.previewGrid,
    previewList: previewList ?? this.previewList,
    previewPictures: previewPictures ?? this.previewPictures,
  );

  @override
  AnchorDensity lerp(AnchorDensity? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}
