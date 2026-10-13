import 'package:flutter/services.dart';

abstract final class Haptics {
  static void selection() => HapticFeedback.selectionClick();

  static void light() => HapticFeedback.lightImpact();

  static void medium() => HapticFeedback.mediumImpact();

  static void success() => HapticFeedback.successNotification();

  static void warning() => HapticFeedback.warningNotification();
}
