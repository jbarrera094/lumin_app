import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai_bridge/method_channel_ai.dart';
import '../../../core/ai_bridge/native_ai_bridge.dart';
import '../../../core/ai_bridge/token_stream.dart';
import '../../../core/harness/context_manager.dart';
import '../domain/models/chat_message.dart';

enum ChatStatus {
  /// The engine is downloading or initializing the model.
  loading,

  /// Ready to take a prompt.
  ready,

  /// A reply is being streamed.
  generating,

  /// The model could not be loaded.
  error,
}

@immutable
class ChatState {
  const ChatState({
    this.status = ChatStatus.loading,
    this.messages = const [],
  });

  final ChatStatus status;
  final List<ChatMessage> messages;

  bool get canSend => status == ChatStatus.ready;

  ChatState copyWith({ChatStatus? status, List<ChatMessage>? messages}) =>
      ChatState(
        status: status ?? this.status,
        messages: messages ?? this.messages,
      );
}

final nativeAiBridgeProvider = Provider<NativeAiBridge>((ref) {
  return MethodChannelAi();
});

class ChatNotifier extends Notifier<ChatState> {
  static const _contextManager = ContextManager();
  static const _generationFailed =
      'Something went wrong while answering. Please try again.';

  late final NativeAiBridge _bridge;
  StreamSubscription<TokenEvent>? _subscription;
  bool _disposed = false;
  int _nextId = 0;

  @override
  ChatState build() {
    _bridge = ref.watch(nativeAiBridgeProvider);
    ref.onDispose(() {
      _disposed = true;
      _subscription?.cancel();
    });

    // Deferred so the provider is mounted before `loadModel` touches its state.
    Future.microtask(loadModel);
    return const ChatState();
  }

  Future<void> loadModel() async {
    _set(state.copyWith(status: ChatStatus.loading));

    try {
      await _bridge.loadModel();
      await _subscription?.cancel();
      if (_disposed) return;
      _subscription = _bridge.tokens.listen(_onTokenEvent);
      _set(state.copyWith(status: ChatStatus.ready));
    } catch (_) {
      _set(state.copyWith(status: ChatStatus.error));
    }
  }

  Future<void> send(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || !state.canSend) return;

    final completed = state.messages;
    final context = _contextManager.contextFor(
      [for (final message in completed) message.toTurn()],
    );

    _set(
      state.copyWith(
        status: ChatStatus.generating,
        messages: [
          ...completed,
          ChatMessage(id: _nextId++, role: AiRole.user, text: prompt),
          ChatMessage(
            id: _nextId++,
            role: AiRole.model,
            text: '',
            isStreaming: true,
          ),
        ],
      ),
    );

    try {
      await _bridge.sendMessage(
        text: prompt,
        history: context.history,
        resetContext: context.resetContext,
      );
    } catch (_) {
      _finishStreaming(fallback: _generationFailed);
    }
  }

  void _onTokenEvent(TokenEvent event) {
    switch (event) {
      case TokenChunk(:final text):
        _appendToStreaming(text);
      case TokenDone():
        _finishStreaming(fallback: _generationFailed);
      case TokenFailure():
        _finishStreaming(fallback: _generationFailed);
    }
  }

  void _appendToStreaming(String text) {
    if (text.isEmpty) return;

    _set(
      state.copyWith(
        messages: [
          for (final message in state.messages)
            if (message.isStreaming)
              message.copyWith(text: message.text + text)
            else
              message,
        ],
      ),
    );
  }

  /// Seals the reply being streamed. [fallback] stands in when nothing was decoded.
  void _finishStreaming({required String fallback}) {
    _set(
      state.copyWith(
        status: ChatStatus.ready,
        messages: [
          for (final message in state.messages)
            if (message.isStreaming)
              message.copyWith(
                text: message.text.isEmpty ? fallback : message.text,
                isStreaming: false,
              )
            else
              message,
        ],
      ),
    );
  }

  void _set(ChatState next) {
    if (_disposed) return;
    state = next;
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
