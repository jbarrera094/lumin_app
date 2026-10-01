import 'token_stream.dart';

/// Who produced a turn in the conversation.
enum AiRole { user, model }

/// A completed turn replayed to the model as context.
class AiTurn {
  const AiTurn({required this.role, required this.text});

  final AiRole role;
  final String text;
}

/// Platform-independent entry point to on-device inference.
abstract interface class NativeAiBridge {
  /// Replies streamed back token by token.
  Stream<TokenEvent> get tokens;

  /// Downloads the weights if needed and initializes the engine.
  Future<void> loadModel();

  /// Starts generating a reply to [text]. Output arrives on [tokens].
  ///
  /// [history] is only replayed when [resetContext] is set; otherwise the engine continues from
  /// the context it already holds.
  Future<void> sendMessage({
    required String text,
    required List<AiTurn> history,
    required bool resetContext,
  });

  /// Stops the reply currently being generated.
  Future<void> cancel();
}
