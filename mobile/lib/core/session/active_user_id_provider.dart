import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../app/app_bootstrap.dart';

part 'active_user_id_provider.g.dart';

@Riverpod(keepAlive: true)
class ActiveUserId extends _$ActiveUserId {
  @override
  String? build() => ref.watch(appBootstrapProvider).userId;

  void set(String? id) => state = id;
}
