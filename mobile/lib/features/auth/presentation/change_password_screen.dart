import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/connectivity_provider.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/form_page.dart';
import '../../../core/widgets/form_submit.dart';
import '../../../l10n/l10n.dart';
import '../data/repository/auth_repository.dart';
import '../domain/account_rules.dart';
import 'auth_error_message.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen>
    with FormSubmit {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _currentFocus = FocusNode();
  final _nextFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _current.addListener(() => setState(() {}));
    _next.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _currentFocus.dispose();
    _nextFocus.dispose();
    super.dispose();
  }

  bool _canChange(bool isOnline) =>
      isOnline &&
      !isSubmitting() &&
      _current.text.isNotEmpty &&
      isNewPasswordValid(_next.text);

  Future<void> _change() => submit(
    () => ref
        .read(authRepositoryProvider)
        .changePassword(_current.text, _next.text),
    onSuccess: () => context.pop(),
    successMessage: context.l10n.passwordChanged,
    onFailure: (error) {
      final errorMessage = authErrorMessageOf(error, context.l10n);
      showError(errorMessage.text, field: errorMessage.field);
      if (errorMessage.field == AuthField.currentPassword) {
        _current.clear();
        _currentFocus.requestFocus();
      } else if (errorMessage.field == AuthField.newPassword) {
        _nextFocus.requestFocus();
      }
    },
  );

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);
    final density = context.density;
    final l10n = context.l10n;
    return FormPage(
      title: l10n.passwordTitle,
      bottomBar: AppButton(
        label: l10n.passwordChange,
        busyLabel: l10n.passwordChanging,
        isBusy: isSubmitting(),
        hasShadow: true,
        onPressed: _canChange(isOnline) ? _change : null,
      ),
      children: [
        FormNotices(
          errorMessage: errorMessage,
          offlineText: l10n.passwordOffline,
        ),
        AppTextField(
          controller: _current,
          focusNode: _currentFocus,
          label: l10n.fieldCurrentPassword,
          isPassword: true,
          enabled: isOnline,
          error: errorOf(AuthField.currentPassword),
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.next,
          onChanged: (_) => clearError(AuthField.currentPassword),
          onSubmitted: (_) => _nextFocus.requestFocus(),
        ),
        SizedBox(height: density.space16),
        AppTextField(
          controller: _next,
          focusNode: _nextFocus,
          label: l10n.fieldNewPassword,
          isPassword: true,
          enabled: isOnline,
          error: errorOf(AuthField.newPassword),
          help: l10n.passwordHelp(minPasswordLength),
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onChanged: (_) => clearError(AuthField.newPassword),
          onSubmitted: (_) {
            if (_canChange(isOnline)) _change();
          },
        ),
      ],
    );
  }
}
