import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lumin_app_v2/app.dart';
import 'package:lumin_app_v2/features/auth/presentation/screens/login_screen.dart';
import 'package:lumin_app_v2/features/home/presentation/screens/home_screen.dart';
import 'package:lumin_app_v2/features/home/providers/chat_provider.dart';

import 'support/ai_test_support.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// The home screen loads the on-device model as soon as it opens, so every
  /// run of the app needs a stand-in engine.
  Widget app(FakeAiBridge bridge) => ProviderScope(
        overrides: [nativeAiBridgeProvider.overrideWithValue(bridge)],
        child: const LuminApp(),
      );

  testWidgets('rejects invalid credentials and stays on login', (tester) async {
    final bridge = FakeAiBridge(blockLoad: true);
    addTearDown(bridge.dispose);

    await tester.pumpWidget(app(bridge));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(find.byKey(const Key('username-field')), 'wrong');
    await tester.enterText(find.byKey(const Key('password-field')), 'wrong');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Invalid username or password'), findsOneWidget);
  });

  testWidgets('logs in with admin credentials and opens the chat', (
    tester,
  ) async {
    final bridge = FakeAiBridge(blockLoad: true);
    addTearDown(bridge.dispose);

    await tester.pumpWidget(app(bridge));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('username-field')), 'admin');
    await tester.enterText(find.byKey(const Key('password-field')), 'admin');
    await tester.tap(find.byKey(const Key('login-button')));
    await settle(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Loading AI model...'), findsOneWidget);

    bridge.pendingLoad.complete();
    await settle(tester);

    expect(find.byKey(const Key('chat-input')), findsOneWidget);
  });
}
