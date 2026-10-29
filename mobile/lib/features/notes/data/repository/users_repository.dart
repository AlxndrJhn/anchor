import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/network/dio_provider.dart';
import '../../domain/user_summary.dart';

part 'users_repository.g.dart';

@Riverpod(keepAlive: true)
UsersRepository usersRepository(Ref ref) {
  final dio = ref.watch(dioProvider);
  return UsersRepository(dio);
}

/// Request errors reach the caller; the Dio logger has already recorded them.
class UsersRepository {
  final Dio _dio;

  UsersRepository(this._dio);

  /// Returns an empty list for a query under 2 characters.
  Future<List<UserSummary>> searchUsers(String query) async {
    if (query.trim().length < 2) {
      return [];
    }

    final response = await _dio.get(
      '/api/users/search',
      queryParameters: {'q': query.trim()},
    );

    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserSummary>> getRecentContacts() async {
    final response = await _dio.get('/api/users/recent-contacts');

    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
