import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_typography.dart';
import 'custom_theme.dart';
import 'tokens/app_color_tokens.dart';
import 'tokens/app_dimensions.dart';
import 'tokens/app_opacity.dart';
import 'tokens/app_palette.dart';
import 'tokens/app_radius.dart';
import 'tokens/app_schemes.dart';
import 'tokens/app_style.dart';

/// Builds the app's [ThemeData], including the component themes.
class AppTheme {
  AppTheme._();

  static final Map<
    (Brightness, DisplayDensity, String, AppStyle, String?),
    ThemeData
  >
  _cache = {};

  static ThemeData light([
    DisplayDensity density = DisplayDensity.standard,
    String scheme = anchorSchemeId,
    AppStyle style = AppStyle.standard,
    CustomTheme? custom,
  ]) => _cached(Brightness.light, density, scheme, style, custom);

  static ThemeData dark([
    DisplayDensity density = DisplayDensity.standard,
    String scheme = anchorSchemeId,
    AppStyle style = AppStyle.standard,
    CustomTheme? custom,
  ]) => _cached(Brightness.dark, density, scheme, style, custom);

  static ThemeData _cached(
    Brightness brightness,
    DisplayDensity density,
    String scheme,
    AppStyle style,
    CustomTheme? custom,
  ) => _cache.putIfAbsent((
    brightness,
    density,
    scheme,
    style,
    custom?.encode(),
  ), () => _build(brightness, density, scheme, style, custom));

  /// The colours for [brightness]: Lo-fi's greys, else the scheme with the
  /// custom theme over it. Null keeps Anchor's hand-tuned palette.
  static SchemePalette? paletteFor(
    Brightness brightness,
    String schemeId,
    AppStyle style, [
    CustomTheme? custom,
  ]) {
    if (style == AppStyle.lofi) return lofiScheme.of(brightness);
    final scheme = schemeById(schemeId);
    if (custom?.of(brightness) == null) return scheme?.of(brightness);
    return custom!.merge((scheme ?? anchorScheme).of(brightness), brightness);
  }

  static ThemeData _build(
    Brightness brightness,
    DisplayDensity density,
    String schemeId,
    AppStyle style,
    CustomTheme? custom,
  ) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    final palette = paletteFor(brightness, schemeId, style, custom);
    final primary =
        palette?.foreground ??
        (isDark ? AppPalette.offWhite : AppPalette.slate);
    final secondary = palette?.mutedForeground ?? AppPalette.slateBlue;
    final accent = palette?.accent ?? AppPalette.burntOrange;
    final background =
        palette?.background ??
        (isDark ? AppPalette.bgDark : AppPalette.bgLight);
    final container =
        palette?.card ??
        (isDark ? AppPalette.surfaceDark : AppPalette.surfaceLight);
    final dims = AppDimensions.of(density);
    var styleTokens = AppStyleTokens.of(
      style,
      primary,
      brightness,
      noteFill: palette?.card,
    );
    // On a pure-black page (OLED) cards get a hairline, as on the web, or a
    // near-black card would vanish into it.
    if (style == AppStyle.standard &&
        palette != null &&
        isTrueBlack(palette.background)) {
      styleTokens = styleTokens.copyWith(
        cardSide: BorderSide(color: palette.border),
      );
    }
    final tokens = _colorTokens(brightness, palette, style, primary);
    final brutal = style == AppStyle.neoBrutalism;
    final lofi = style == AppStyle.lofi;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette?.accentStrong ?? AppPalette.slateBlue,
      primary: primary,
      secondary: secondary,
      tertiary: accent,
      surface: background,
      onSurface: primary,
      error: palette?.destructive,
      outline: palette?.border,
      brightness: brightness,
    );

    final fabBackground = lofi || brutal
        ? container
        : palette?.accentStrong ??
              (isDark ? AppPalette.burntOrange : AppPalette.slate);
    final fabForeground = lofi || brutal
        ? primary
        : palette == null
        ? Colors.white
        : _onColor(fabBackground);
    final sharpCorners = brutal
        ? const BorderRadius.all(Radius.circular(6))
        : null;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: AppTypography.buildTextTheme(base.textTheme, style),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: Platform.isIOS,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: primary),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: brightness, // iOS
          statusBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark, // Android
          statusBarColor: Colors.transparent,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: container,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: styleTokens.cardRadius,
          side: styleTokens.cardSide,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: fabBackground,
        foregroundColor: fabForeground,
        elevation: lofi || brutal ? 0 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: lofi
              ? AppStyleTokens.wobbly
              : sharpCorners ?? AppRadius.fabBorder,
          side: lofi || brutal ? styleTokens.cardSide : BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: dims.buttonPadding,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: dims.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: sharpCorners ?? AppRadius.buttonBorder,
          ),
          side: brutal || lofi
              ? styleTokens.cardSide
              : BorderSide(color: primary.withValues(alpha: AppOpacity.border)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBorder,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: tokens.subtleBorder,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: container,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: lofi
              ? AppStyleTokens.wobbly
              : sharpCorners ?? AppRadius.sheetBorder,
          side: styleTokens.cardSide,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: container,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetBorder,
        ),
        headerBackgroundColor: container,
        headerForegroundColor: primary,
        dayShape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: container,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetBorder,
        ),
        hourMinuteShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
        ),
        dialBackgroundColor: secondary.withValues(alpha: AppOpacity.subtleFill),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTopBorder),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: container,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlBorder,
          side: brutal || lofi
              ? styleTokens.cardSide
              : BorderSide(
                  color: primary.withValues(alpha: AppOpacity.hairline),
                ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.inputFill,
        border: OutlineInputBorder(
          borderRadius: sharpCorners ?? AppRadius.mdBorder,
          borderSide: brutal || lofi ? styleTokens.cardSide : BorderSide.none,
        ),
        enabledBorder: brutal || lofi
            ? OutlineInputBorder(
                borderRadius: sharpCorners ?? AppRadius.mdBorder,
                borderSide: styleTokens.cardSide,
              )
            : null,
        contentPadding: EdgeInsets.all(dims.lg),
        hintStyle: TextStyle(color: secondary.withValues(alpha: 0.5)),
      ),
      extensions: [dims, tokens, styleTokens],
    );
  }

  /// Black, or so close to it that an OLED screen leaves the pixel off.
  static bool isTrueBlack(Color color) => color.computeLuminance() < 0.001;

  /// White or near-black, whichever reads on [color].
  static Color _onColor(Color color) =>
      color.computeLuminance() > 0.45 ? const Color(0xFF1B1B1B) : Colors.white;

  /// Anchor's tokens, recoloured for a scheme and adjusted for a style.
  static AppColorTokens _colorTokens(
    Brightness brightness,
    SchemePalette? palette,
    AppStyle style,
    Color ink,
  ) {
    final isDark = brightness == Brightness.dark;
    var tokens = AppColorTokens.of(brightness);
    if (palette != null) {
      tokens = tokens.copyWith(
        pageGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.background, palette.sidebar],
        ),
        sheetGradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.card, palette.background],
        ),
        subtleBorder: ink.withValues(alpha: 0.08),
        cardFill: palette.card.withValues(alpha: isDark ? 0.85 : 0.9),
        inputFill: palette.muted.withValues(alpha: 0.7),
        shimmerBase: palette.muted,
        shimmerHighlight: Color.lerp(palette.muted, palette.card, 0.6),
      );
    }
    final card =
        palette?.card ?? (isDark ? AppPalette.surfaceDark : Colors.white);
    return switch (style) {
      AppStyle.standard => tokens,
      AppStyle.skeuomorphism => tokens.copyWith(
        subtleBorder: ink.withValues(alpha: 0.1),
        cardFill: card,
        cardShadow: BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.2),
          blurRadius: 16,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
      ),
      AppStyle.neoBrutalism => tokens.copyWith(
        subtleBorder: ink,
        cardFill: card,
        inputFill: card,
        cardShadow: BoxShadow(color: ink, offset: const Offset(4, 4)),
        sheetShadow: BoxShadow(color: ink, offset: const Offset(0, -3)),
      ),
      AppStyle.lofi => tokens.copyWith(
        subtleBorder: ink.withValues(alpha: 0.6),
        cardFill: card,
        inputFill: card,
        cardShadow: const BoxShadow(color: Colors.transparent),
        sheetShadow: const BoxShadow(color: Colors.transparent),
      ),
    };
  }
}
