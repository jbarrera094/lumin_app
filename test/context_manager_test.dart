import 'package:flutter_test/flutter_test.dart';
import 'package:lumin_app_v2/core/ai_bridge/native_ai_bridge.dart';
import 'package:lumin_app_v2/core/harness/context_manager.dart';

List<AiTurn> turns(int count) => [
      for (var i = 0; i < count; i++)
        AiTurn(
          role: i.isEven ? AiRole.user : AiRole.model,
          text: 'turn $i',
        ),
    ];

void main() {
  const manager = ContextManager();

  test('keeps the engine context while the conversation fits the window', () {
    // 9 completed turns plus the prompt about to be sent is exactly the cap.
    final context = manager.contextFor(turns(9));

    expect(context.resetContext, isFalse);
    expect(context.history, isEmpty);
  });

  test('replays only the most recent turns once the window overflows', () {
    final context = manager.contextFor(turns(12));

    expect(context.resetContext, isTrue);
    // 9 replayed turns leave room for the prompt, for 10 messages of context.
    expect(context.history, hasLength(9));
    expect(context.history.first.text, 'turn 3');
    expect(context.history.last.text, 'turn 11');
  });

  test('never sends more than maxMessages including the prompt', () {
    for (var completed = 0; completed <= 40; completed++) {
      final context = manager.contextFor(turns(completed));
      expect(context.history.length + 1, lessThanOrEqualTo(manager.maxMessages));
    }
  });
}
