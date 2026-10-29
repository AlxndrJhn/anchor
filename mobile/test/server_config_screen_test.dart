import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/page_bar.dart';
import 'package:anchor/features/server/presentation/harbor_illustration.dart';
import 'package:anchor/features/server/presentation/server_config_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isOnlineProvider.overrideWithValue(true)],
        child: MaterialApp(theme: AppTheme.light(), home: home),
      ),
    );
    await tester.pump();
  }

  String addressOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('the first start asks for the server with no way back', (
    tester,
  ) async {
    await pumpApp(tester, const ServerConfigScreen());

    expect(find.byType(HarborIllustration), findsOneWidget);
    expect(find.text('Welcome to Anchor'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byType(PageBackButton), findsNothing);
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
    expect(find.text('Welcome to Anchor'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byType(PageBackButton), findsOneWidget);
    expect(addressOf(tester), 'anchor.example.com');
  });
}
