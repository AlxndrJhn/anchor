import 'package:dio/dio.dart';

import '../../l10n/app_localizations.dart';
import 'api_error.dart';

String apiErrorText(Object error, AppLocalizations l10n) {
  final apiError = switch (error) {
    ApiError() => error,
    DioException() => error.apiError,
    _ => null,
  };
  return switch (apiError) {
    OfflineApiError() => l10n.errorOffline,
    TimeoutApiError() => l10n.errorTimeout,
    CertificateApiError() => l10n.errorCertificate,
    CancelledApiError() => l10n.errorCancelled,
    UnauthorizedApiError() => l10n.errorSignInAgain,
    ForbiddenApiError() => l10n.errorForbidden,
    NotFoundApiError() => l10n.errorNotFound,
    UpgradeRequiredApiError() => l10n.errorIncompatible,
    ValidationApiError() => l10n.errorCheckInput,
    ServerApiError(:final statusCode?) when statusCode >= 500 =>
      l10n.errorServer,
    ServerApiError() || null => l10n.errorGeneric,
  };
}
