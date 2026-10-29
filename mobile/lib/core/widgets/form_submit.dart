import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../motion/haptics.dart';
import '../network/connectivity_provider.dart';
import 'app_snackbar.dart';

mixin FormSubmit<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Object? _running;
  String? _errorMessage;
  final Map<Object, String> _fieldErrors = {};

  String? get errorMessage => _errorMessage;

  String? errorOf(Object field) => _fieldErrors[field];

  bool isSubmitting([Object? tag]) =>
      tag == null ? _running != null : _running == tag;

  void clearError(Object field) {
    if (_fieldErrors.containsKey(field)) {
      setState(() => _fieldErrors.remove(field));
    }
  }

  void showError(String text, {Object? field}) {
    setState(() {
      if (field == null) {
        _errorMessage = text;
      } else {
        _fieldErrors[field] = text;
      }
    });
  }

  /// Returns whether all passed; if not, the first field with a problem
  /// takes focus.
  bool checkFields(
    List<(Object field, FocusNode focus, String? error)> checks,
  ) {
    setState(() {
      _errorMessage = null;
      _fieldErrors.clear();
      for (final (field, _, error) in checks) {
        if (error != null) _fieldErrors[field] = error;
      }
    });
    final firstFailed = checks.where((check) => check.$3 != null).firstOrNull;
    if (firstFailed == null) return true;
    Haptics.warning();
    firstFailed.$2.requestFocus();
    return false;
  }

  /// Returns false without running [action] while offline or while another
  /// action runs. The callbacks run only while mounted.
  Future<bool> submit(
    Future<void> Function() action, {
    required ValueChanged<Object> onFailure,
    VoidCallback? onSuccess,
    String? successMessage,
    Object tag = #submit,
  }) async {
    if (_running != null) return false;
    if (!ref.read(isOnlineProvider)) {
      Haptics.warning();
      return false;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _running = tag;
      _errorMessage = null;
      _fieldErrors.clear();
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        Haptics.warning();
        onFailure(error);
      }
      return false;
    } finally {
      if (mounted) setState(() => _running = null);
    }
    if (!mounted) return true;
    onSuccess?.call();
    if (successMessage != null) {
      AppSnackbar.show(context, successMessage, kind: SnackbarKind.success);
    }
    return true;
  }
}
