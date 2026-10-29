import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/network/server_config_provider.dart';
import '../data/remote/auth_service.dart';
import '../domain/oidc_config.dart';

part 'oidc_config_provider.g.dart';

@riverpod
Future<OidcConfig> oidcConfig(Ref ref) async {
  final serverUrl = ref.watch(serverUrlProvider);
  if (serverUrl == null || serverUrl.isEmpty) {
    return const OidcConfig();
  }
  // Asks again once the phone is back online.
  ref.watch(isOnlineProvider);
  final authService = ref.watch(authServiceProvider);
  return authService.getOidcConfig();
}
