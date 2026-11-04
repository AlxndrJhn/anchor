import 'dart:io';

import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/network/server_headers.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/page_bar.dart';
import 'package:anchor/features/server/presentation/harbor_illustration.dart';
import 'package:anchor/features/server/presentation/server_config_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Saved extends SavedServerHeaders {
  _Saved(this.saved);

  final ServerHeaders? saved;

  @override
  Future<ServerHeaders?> build() async => saved;
}

void main() {
  Future<void> pumpApp(
    WidgetTester tester,
    Widget home, {
    ServerHeaders? savedHeaders,
  }) async {
    // Tall enough for Advanced, below the fold on a phone.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          savedServerHeadersProvider.overrideWith(() => _Saved(savedHeaders)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: home),
      ),
    );
    await tester.pump();
  }

  String addressOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first).controller!.text;

  String headersOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).last).controller!.text;

  testWidgets('the first start asks for the server, or to go on without one', (
    tester,
  ) async {
    await pumpApp(tester, const ServerConfigScreen());

    expect(find.byType(HarborIllustration), findsOneWidget);
    expect(find.textContaining('Welcome to Anchor'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byType(PageBackButton), findsNothing);
    expect(find.text('Use without a server'), findsOneWidget);
    expect(addressOf(tester), isEmpty);
  });

  testWidgets('from sign in, the same page opens with the address and a '
      'way back', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ServerConfigScreen(
                initialUrl: 'https://anchor.example.com',
              ),
            ),
          ),
          child: const Text('Sign in'),
        ),
      ),
    );
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(HarborIllustration), findsOneWidget);
    expect(find.textContaining('Welcome to Anchor'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byType(PageBackButton), findsOneWidget);
    expect(find.text('Use without a server'), findsNothing);
    expect(addressOf(tester), 'anchor.example.com');
  });

  testWidgets('saved headers show under Advanced, already open', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const ServerConfigScreen(initialUrl: 'https://notes.example.com'),
      savedHeaders: const ServerHeaders(
        server: 'https://notes.example.com',
        text: 'CF-Access-Client-Id: abc',
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Extra headers'), findsOneWidget);
    expect(headersOf(tester), 'CF-Access-Client-Id: abc');
  });

  testWidgets('a header line that is wrong is pointed out, and nothing '
      'connects', (tester) async {
    await pumpApp(tester, const ServerConfigScreen());
    await tester.enterText(find.byType(TextField).first, 'notes.example.com');
    await tester.tap(find.text('Advanced'));
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(
      find.byType(TextField).last,
      'X-Token: 1\nAuthorization: Bearer x',
    );

    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Line 2: Anchor sets this header itself.'),
      findsOneWidget,
    );
    expect(find.text('Connecting…'), findsNothing);
  });

  group('when the server can\'t be reached', () {
    late _RefusingHttp http;
    final overrides = HttpOverrides.current;

    setUp(() => HttpOverrides.global = http = _RefusingHttp());
    tearDown(() => HttpOverrides.global = overrides);

    Future<void> settleRequest(WidgetTester tester) =>
        tester.pump(const Duration(milliseconds: 200));

    Future<void> connect(WidgetTester tester, String address) async {
      await tester.enterText(find.byType(TextField), address);
      await tester.tap(find.text('Continue'));
      await settleRequest(tester);
    }

    Future<void> comeBackToTheApp(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleRequest(tester);
    }

    testWidgets('coming back to the app tries the same address again', (
      tester,
    ) async {
      await pumpApp(tester, const ServerConfigScreen());
      await connect(tester, 'http://192.168.1.2:3001');
      expect(http.attempts, 1);
      expect(find.textContaining('Couldn’t reach'), findsOneWidget);

      await comeBackToTheApp(tester);
      expect(http.attempts, 2);
    });

    testWidgets('coming back doesn\'t try an address changed since', (
      tester,
    ) async {
      await pumpApp(tester, const ServerConfigScreen());
      await connect(tester, 'http://192.168.1.2:3001');
      await tester.enterText(find.byType(TextField), 'http://192.168.1.3');

      await comeBackToTheApp(tester);
      expect(http.attempts, 1);
    });
  });
}

class _RefusingHttp extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _RefusingClient(this);
}

class _RefusingClient implements HttpClient {
  _RefusingClient(this.http);

  final _RefusingHttp http;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    http.attempts++;
    return Future.error(const SocketException('Network is down'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
