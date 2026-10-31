import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/redaction.dart';
import 'debug_privacy.dart';
import 'debug_recorder_controller.dart';

/// Writes provider updates into the debug recording. Does nothing unless
/// debug mode is recording.
final class DebugStateObserver extends ProviderObserver {
  const DebugStateObserver();

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    final recorder = DebugRecorder.instance;
    if (!recorder.isRecording) return;
    final provider = context.provider;
    recorder.record('provider', {
      'provider': provider.name ?? provider.runtimeType.toString(),
      'value': describeStateValue(newValue),
    });
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final recorder = DebugRecorder.instance;
    if (!recorder.isRecording) return;
    final provider = context.provider;
    recorder.record('provider_error', {
      'provider': provider.name ?? provider.runtimeType.toString(),
      'error': describeStateValue(error),
    });
  }
}

/// Fields whose values stay out of reports: credentials and addresses.
final _sensitiveField = RegExp(
  r'(\w*(?:password|token|secret|email|authorization|pin|pattern)\w*)'
  r'(\s*[:=]\s*)([^,;)}\]\s]+)',
  caseSensitive: false,
);

/// [value] as a short, redacted line for the report, its shape without
/// its words (see [keepShape]). A list says how long
/// it is and shows its first item, rather than spelling out every one.
String describeStateValue(Object? value) {
  var v = value;
  if (v is AsyncValue) {
    if (v.hasError) return 'AsyncError(${_line(v.error)})';
    if (!v.hasValue) return 'AsyncLoading()';
    v = v.value;
  }
  if (v is Map) {
    return _line(redactMap({for (final e in v.entries) '${e.key}': e.value}));
  }
  if (v is Iterable && v is! String) {
    final first = v.isEmpty ? '' : ', first: ${_line(v.first)}';
    return '${v.runtimeType}(length: ${v.length}$first)';
  }
  return _line(v);
}

String _line(Object? value) => DebugRecorder.truncateValue(
  keepShape(
    '$value'.replaceAllMapped(_sensitiveField, (m) => '${m[1]}${m[2]}***'),
  ),
);
