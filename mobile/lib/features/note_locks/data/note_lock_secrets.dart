import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/providers/active_user_id_provider.dart';
import 'lock_hash.dart';

part 'note_lock_secrets.g.dart';

const _tag = 'NoteLocks';

/// The PIN or the pattern; one of each per account.
enum LockSecretKind { pin, pattern }

/// The account's PIN and pattern, as hashes the app checks offline.
class NoteLockSecrets {
  const NoteLockSecrets({this.pin, this.pattern, this.hasPassword = true});

  static const none = NoteLockSecrets();

  factory NoteLockSecrets.fromJson(Map<String, dynamic> json) =>
      NoteLockSecrets(
        pin: json['pin'] as String?,
        pattern: json['pattern'] as String?,
        hasPassword: json['hasPassword'] as bool? ?? true,
      );

  final String? pin;
  final String? pattern;

  /// False for single sign-on accounts, which can't prove themselves with a
  /// password when the PIN or pattern is forgotten.
  final bool hasPassword;

  String? hashOf(LockSecretKind kind) => switch (kind) {
    LockSecretKind.pin => pin,
    LockSecretKind.pattern => pattern,
  };

  bool has(LockSecretKind kind) => hashOf(kind) != null;

  Map<String, dynamic> toJson() => {
    'pin': pin,
    'pattern': pattern,
    'hasPassword': hasPassword,
  };
}

/// Why setting a PIN or pattern didn't work, in words for the person.
class LockSecretException implements Exception {
  const LockSecretException(this.message, {this.isWrongProof = false});

  final String message;

  /// The old PIN, pattern or password was wrong.
  final bool isWrongProof;

  @override
  String toString() => message;
}

@riverpod
NoteLocksApi noteLocksApi(Ref ref) => NoteLocksApi(ref.watch(dioProvider));

/// /api/note-locks on the server.
class NoteLocksApi {
  NoteLocksApi(this._dio);

  final Dio _dio;

  Future<NoteLockSecrets> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/note-locks');
    return NoteLockSecrets.fromJson(response.data ?? const {});
  }

  /// Sets or replaces the PIN or pattern. Replacing one takes [current] (the
  /// old one) or the account [password].
  Future<NoteLockSecrets> set(
    LockSecretKind kind,
    String secret, {
    String? current,
    String? password,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/api/note-locks/${kind.name}',
        data: {'secret': secret, 'current': ?current, 'password': ?password},
      );
      return NoteLockSecrets.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final what = kind == LockSecretKind.pin ? 'PIN' : 'pattern';
      if (status == 403) {
        throw LockSecretException(
          'Wrong $what or password',
          isWrongProof: true,
        );
      }
      if (status == 400) {
        throw LockSecretException(
          kind == LockSecretKind.pin
              ? 'A PIN is 4 to 12 digits'
              : 'A pattern joins at least 4 dots',
        );
      }
      if (status == 404) {
        throw const LockSecretException(
          'Your server doesn’t support note locks yet',
        );
      }
      throw LockSecretException(
        'Couldn’t save the $what. It needs a connection to the server.',
      );
    }
  }

  /// Checks a PIN or pattern on the server, for when this device has no
  /// copy of it yet.
  Future<bool> verify(LockSecretKind kind, String secret) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/note-locks/verify',
      data: {'kind': kind.name, 'secret': secret},
    );
    return response.data?['ok'] == true;
  }
}

/// The account's PIN and pattern hashes, kept in secure storage so locked
/// notes open offline, and fetched again on start, after each sync and when
/// Settings opens.
@Riverpod(keepAlive: true)
class NoteLockSecretsController extends _$NoteLockSecretsController {
  static const _storage = FlutterSecureStorage();

  String? _userId;

  String get _key => 'note_locks_$_userId';

  @override
  Future<NoteLockSecrets> build() async {
    _userId = ref.watch(activeUserIdProvider);
    if (_userId == null) return NoteLockSecrets.none;

    ref.listen<bool>(syncManagerProvider, (wasSyncing, isSyncing) {
      if (wasSyncing == true && !isSyncing) unawaited(refresh());
    });

    final cached = await _read();
    Future.microtask(refresh);
    return cached ?? NoteLockSecrets.none;
  }

  Future<NoteLockSecrets?> _read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      return NoteLockSecrets.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.instance.warn(_tag, 'Couldn’t read the cached locks: $e');
      return null;
    }
  }

  Future<void> _keep(NoteLockSecrets secrets) async {
    state = AsyncData(secrets);
    try {
      await _storage.write(key: _key, value: jsonEncode(secrets.toJson()));
    } catch (e) {
      AppLogger.instance.warn(_tag, 'Couldn’t cache the locks: $e');
    }
  }

  /// Asks the server; null (and the cached copy kept) when it can't be
  /// reached.
  Future<NoteLockSecrets?> refresh() async {
    final userId = _userId;
    if (userId == null) return null;
    try {
      final secrets = await ref.read(noteLocksApiProvider).fetch();
      if (_userId != userId) return null;
      await _keep(secrets);
      return secrets;
    } on DioException catch (e) {
      AppLogger.instance.debug(_tag, 'Locks not refreshed: ${e.type.name}');
      return null;
    }
  }

  /// Sets or replaces the PIN or pattern on the server. Throws a
  /// [LockSecretException].
  Future<NoteLockSecrets> setSecret(
    LockSecretKind kind,
    String secret, {
    String? current,
    String? password,
  }) async {
    final secrets = await ref
        .read(noteLocksApiProvider)
        .set(kind, secret, current: current, password: password);
    await _keep(secrets);
    AppLogger.instance.info(_tag, 'Set the ${kind.name}');
    return secrets;
  }

  /// Whether [secret] is the account's PIN or pattern: checked here against
  /// the cached hash, or by the server when there is none yet. Null when
  /// neither can tell (no copy here and no connection).
  Future<bool?> verify(LockSecretKind kind, String secret) async {
    NoteLockSecrets? cached;
    try {
      cached = await future;
    } catch (_) {
      cached = null;
    }
    final known = cached?.hashOf(kind) ?? (await refresh())?.hashOf(kind);
    if (known != null) {
      if (await verifyLockSecret(secret, known)) return true;
      // Maybe changed on another device since.
      final fresh = (await refresh())?.hashOf(kind);
      if (fresh == null || fresh == known) return false;
      return verifyLockSecret(secret, fresh);
    }
    try {
      return await ref.read(noteLocksApiProvider).verify(kind, secret);
    } on DioException {
      return null;
    }
  }
}

/// Whether [secret] has the shape the server takes for [kind].
bool isValidLockSecret(LockSecretKind kind, String secret) => switch (kind) {
  LockSecretKind.pin => isValidPin(secret),
  LockSecretKind.pattern => isValidPattern(secret),
};
