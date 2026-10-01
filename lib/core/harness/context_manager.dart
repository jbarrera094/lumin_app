import '../ai_bridge/native_ai_bridge.dart';

/// What the engine needs in order to answer the next prompt.
class ChatContext {
  const ChatContext({required this.history, required this.resetContext});

  /// Turns to replay. Empty unless [resetContext] is set.
  final List<AiTurn> history;

  /// Whether the engine should drop the context it holds and start from [history].
  final bool resetContext;
}

/// Caps how much of the conversation is handed to the model.
///
/// The engine keeps its own KV cache, so as long as the conversation fits in the window the next
/// prompt is all it needs. Once it no longer fits, the context is rebuilt from the most recent
/// turns instead, which bounds memory use.
class ContextManager {
  const ContextManager({this.maxMessages = 10}) : assert(maxMessages > 1);

  /// Total messages sent as context, counting the prompt about to be sent.
  final int maxMessages;

  ChatContext contextFor(List<AiTurn> completed) {
    if (completed.length + 1 <= maxMessages) {
      return const ChatContext(history: [], resetContext: false);
    }

    return ChatContext(
      history: completed.sublist(completed.length - (maxMessages - 1)),
      resetContext: true,
    );
  }
}
