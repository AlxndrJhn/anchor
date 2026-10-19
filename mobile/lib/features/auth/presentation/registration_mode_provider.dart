import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/network/server_config_provider.dart';
import '../data/remote/auth_service.dart';
import '../domain/registration_mode.dart';

part 'registration_mode_provider.g.dart';

@riverpod
Future<RegistrationMode> registrationMode(Ref ref) async {
  final serverUrl = ref.watch(serverUrlProvider);
  if (serverUrl == null || serverUrl.isEmpty) {
    return RegistrationMode.enabled;
  }
  // Asks again once the phone is back online.
  ref.watch(isOnlineProvider);
  final authService = ref.watch(authServiceProvider);
  return RegistrationMode.parse(await authService.getRegistrationMode());
}
