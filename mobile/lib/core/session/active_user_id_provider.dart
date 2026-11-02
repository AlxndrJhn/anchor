import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../app/app_bootstrap.dart';

part 'active_user_id_provider.g.dart';

/// Whose notes are open while no server is set: this device's own, kept in
/// their own database until an account takes them over at sign in.
const localUserId = 'local';

@Riverpod(keepAlive: true)
class ActiveUserId extends _$ActiveUserId {
  @override
  String? build() => ref.watch(appBootstrapProvider).userId;

  void set(String? id) => state = id;
}

/// Whether the open notes stay on this device, with no server to sync with.
@Riverpod(keepAlive: true)
bool isLocalOnly(Ref ref) => ref.watch(activeUserIdProvider) == localUserId;
