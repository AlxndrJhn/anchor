import 'dart:async';

import 'package:anchor/core/logging/app_logger.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Runs around every test file in this package (flutter_test convention).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Only the console is quieted; the log buffer still records everything.
  AppLogger.instance.consoleLevel = LogLevel.warn;
  await initializeDateFormatting();
  await testMain();
}
