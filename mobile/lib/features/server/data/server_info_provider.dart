import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../core/network/dio_provider.dart';

part 'server_info_provider.g.dart';

class ServerInfo {
  /// Null when the server doesn't say.
  final String? version;
  final String app;

  /// Empty for servers too old to advertise them.
  final List<int> protocols;

  ServerInfo({this.version, required this.app, this.protocols = const []});

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      version: json['version'] as String?,
      app: json['app'] as String? ?? 'Unknown',
      protocols:
          (json['protocols'] as List?)?.whereType<int>().toList() ?? const [],
    );
  }
}

@riverpod
Future<ServerInfo?> serverInfo(Ref ref) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/api/health');

    if (response.statusCode == 200) {
      return ServerInfo.fromJson(response.data);
    }
    return null;
  } catch (error) {
    AppLogger.instance.warn(
      LogTags.settings,
      'Reading the server info failed',
      error: error,
    );
    return null;
  }
}
