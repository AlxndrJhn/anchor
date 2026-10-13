import 'package:flutter/services.dart';

/// See-through status and navigation bars, with icons for the theme.
SystemUiOverlayStyle systemBarsStyle({required bool dark}) =>
    SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: const Color(0x00000000),
      systemNavigationBarDividerColor: const Color(0x00000000),
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
