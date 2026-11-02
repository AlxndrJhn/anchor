import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/auth/data/remote/auth_service.dart';
import 'package:anchor/features/auth/data/repository/auth_repository.dart';
import 'package:anchor/features/auth/domain/device_session.dart';
import 'package:anchor/features/settings/presentation/devices_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _Devices extends AuthRepository {
  _Devices(this.sessions)
    : super(AuthService(Dio()), const FlutterSecureStorage());

  final List<DeviceSession> sessions;
  final revoked = <String>[];

  @override
  Future<List<DeviceSession>> listSessions() async =>
      sessions.where((s) => !revoked.contains(s.id)).toList();

  @override
  Future<void> revokeSession(String id) async => revoked.add(id);
}

DeviceSession _session(String id, String device, {bool isCurrent = false}) =>
    DeviceSession(
      id: id,
      device: device,
      signedInAt: DateTime(2026, 10, 1),
      lastActiveAt: DateTime(2026, 10, 30),
      isCurrent: isCurrent,
    );

void main() {
  testWidgets('lists the devices and signs one out', (tester) async {
    final devices = _Devices([
      _session('phone', 'Anchor+ app on Android', isCurrent: true),
      _session('laptop', 'Chrome on Windows'),
      _session('tablet', 'Safari on iOS'),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(devices)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DevicesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Anchor+ app on Android'), findsOneWidget);
    expect(find.text('This phone'), findsOneWidget);
    expect(find.text('Chrome on Windows'), findsOneWidget);
    // One per other device; this phone has none.
    expect(find.text('Sign out'), findsNWidgets(2));
    expect(find.text('Sign out other devices'), findsOneWidget);

    await tester.tap(find.text('Sign out').first);
    await tester.pumpAndSettle();

    expect(devices.revoked, ['laptop']);
    expect(find.text('Chrome on Windows'), findsNothing);
    // One other device left: signing out "the others" adds nothing.
    expect(find.text('Sign out other devices'), findsNothing);
  });
}
