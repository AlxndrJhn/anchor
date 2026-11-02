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
}
