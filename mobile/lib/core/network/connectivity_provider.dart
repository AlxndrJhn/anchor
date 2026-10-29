import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

bool isOnlineFromResults(List<ConnectivityResult> results) =>
    results.isNotEmpty && !results.contains(ConnectivityResult.none);

@Riverpod(keepAlive: true)
Stream<List<ConnectivityResult>> connectivityStream(Ref ref) {
  return Connectivity().onConnectivityChanged;
}

@riverpod
bool isOnline(Ref ref) {
  final connectivity = ref.watch(connectivityStreamProvider);
  return connectivity.maybeWhen(data: isOnlineFromResults, orElse: () => true);
}
