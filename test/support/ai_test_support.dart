import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumin_app_v2/core/ai_bridge/native_ai_bridge.dart';
import 'package:lumin_app_v2/core/ai_bridge/token_stream.dart';

/// Stands in for the Android engine and records what the chat asked it to do.
///
/// Build this inside the test body, never in `setUp`: its [Completer] and
/// [StreamController] must belong to the fake-async zone that `testWidgets`
/// installs, or completing them will not resume anything the test can pump.
class FakeAiBridge implements NativeAiBridge {
  FakeAiBridge({this.failLoad = false, this.blockLoad = false});

  /// Makes [loadModel] throw, which drives the error dialog.
  bool failLoad;

  /// Holds [loadModel] open until [pendingLoad] completes, so the loading state
  /// can be observed.
  bool blockLoad;

  final _tokens = StreamController<TokenEvent>.broadcast();
  final pendingLoad = Completer<void>();
  final prompts = <String>[];
  final histories = <List<AiTurn>>[];
  final resets = <bool>[];

  int loadAttempts = 0;

  @override
  Stream<TokenEvent> get tokens => _tokens.stream;

  @override
  Future<void> loadModel() async {
    loadAttempts++;
    if (blockLoad) await pendingLoad.future;
    if (failLoad) throw StateError('model unavailable');
  }

  @override
  Future<void> sendMessage({
    required String text,
    required List<AiTurn> history,
    required bool resetContext,
  }) async {
    prompts.add(text);
    histories.add(history);
    resets.add(resetContext);
  }

  @override
  Future<void> cancel() async {}

  void emit(TokenEvent event) => _tokens.add(event);

  void dispose() => _tokens.close();
}

/// Advances a few frames.
///
/// [WidgetTester.pumpAndSettle] cannot be used here: the loading overlay and the
/// streaming bubble both show a progress indicator, which never stops animating.
Future<void> settle(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
