import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/session/active_user_id_provider.dart';
import '../../features/auth/presentation/auth_controller.dart';
import 'app_router.dart';

class PendingLaunchRoute {
  /// Call from the owning provider's build.
  PendingLaunchRoute(this._ref) {
    _ref.listen(authControllerProvider, (_, _) => _flush());
  }

  final Ref _ref;
  String? _route;

  void open(String route) {
    _route = route;
    _flush();
  }

  void _flush() {
    final route = _route;
    if (route == null) return;
    if (_ref.read(authControllerProvider).isLoading) return;

    _route = null;
    if (_ref.read(activeUserIdProvider) == null) return;

    _ref.read(goRouterProvider).go(route);
  }
}
