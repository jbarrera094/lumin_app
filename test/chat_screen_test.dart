import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lumin_app_v2/core/ai_bridge/token_stream.dart';
import 'package:lumin_app_v2/core/theme/app_theme.dart';
import 'package:lumin_app_v2/features/home/presentation/screens/home_screen.dart';
import 'package:lumin_app_v2/features/home/presentation/widgets/chat_bubble.dart';
import 'package:lumin_app_v2/features/home/providers/chat_provider.dart';

import 'support/ai_test_support.dart';

Widget wrap(FakeAiBridge bridge) {
  return ProviderScope(
    overrides: [nativeAiBridgeProvider.overrideWithValue(bridge)],
    child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows a spinner and the loading copy while the model loads', (
    tester,
  ) async {
    final bridge = FakeAiBridge(blockLoad: true);
    addTearDown(bridge.dispose);

    await tester.pumpWidget(wrap(bridge));
    await settle(tester);

    expect(find.text('Loading AI model...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('chat-input')), findsNothing);

    bridge.pendingLoad.complete();
    await settle(tester);

    expect(find.text('Loading AI model...'), findsNothing);
    expect(find.byKey(const Key('chat-input')), findsOneWidget);
  });

  testWidgets('offers a retry when the model fails to load', (tester) async {
    final bridge = FakeAiBridge(failLoad: true);
    addTearDown(bridge.dispose);

    await tester.pumpWidget(wrap(bridge));
    await settle(tester);

    expect(find.byKey(const Key('model-error-dialog')), findsOneWidget);
    expect(
      find.text("Couldn't load the AI model. Please try again."),
      findsOneWidget,
    );
    expect(bridge.loadAttempts, 1);

    bridge.failLoad = false;
    await tester.tap(find.byKey(const Key('model-retry-button')));
    await settle(tester);

    expect(bridge.loadAttempts, 2);
    expect(find.byKey(const Key('model-error-dialog')), findsNothing);
    expect(find.byKey(const Key('chat-input')), findsOneWidget);
  });

  testWidgets('streams a reply into a bubble and re-enables the composer', (
    tester,
  ) async {
    final bridge = FakeAiBridge();
    addTearDown(bridge.dispose);

    await tester.pumpWidget(wrap(bridge));
    await settle(tester);

    final sendButton = find.byKey(const Key('chat-send-button'));
    expect(tester.widget<IconButton>(sendButton).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('chat-input')), 'Hello there');
    await tester.pump();
    expect(tester.widget<IconButton>(sendButton).onPressed, isNotNull);

    await tester.tap(sendButton);
    await settle(tester);

    expect(bridge.prompts, ['Hello there']);
    expect(bridge.resets, [false]);
    expect(find.text('Hello there'), findsOneWidget);
    // The user turn plus the placeholder for the streaming reply.
    expect(find.byType(ChatBubble), findsNWidgets(2));
    // Nothing else can be sent until the reply lands.
    expect(tester.widget<IconButton>(sendButton).onPressed, isNull);

    bridge.emit(const TokenChunk('Hi '));
    bridge.emit(const TokenChunk('back!'));
    await settle(tester);
    expect(find.text('Hi back!'), findsOneWidget);

    bridge.emit(const TokenDone());
    await settle(tester);

    expect(find.text('Hi back!'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('chat-input'))).enabled,
      isTrue,
    );
  });

  testWidgets('replays a trimmed history once the context window overflows', (
    tester,
  ) async {
    final bridge = FakeAiBridge();
    addTearDown(bridge.dispose);

    await tester.pumpWidget(wrap(bridge));
    await settle(tester);

    for (var turn = 0; turn < 6; turn++) {
      await tester.enterText(
        find.byKey(const Key('chat-input')),
        'prompt $turn',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send-button')));
      await settle(tester);

      bridge.emit(TokenChunk('reply $turn'));
      bridge.emit(const TokenDone());
      await settle(tester);
    }

    // Each turn adds two messages, so the sixth prompt is the first that cannot
    // fit alongside the ten already exchanged.
    expect(bridge.resets, [false, false, false, false, false, true]);
    expect(bridge.histories.last, hasLength(9));
    expect(bridge.histories.last.last.text, 'reply 4');
  });
}
