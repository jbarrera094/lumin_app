import 'package:flutter/services.dart';

/// A single event emitted by the native inference engine while it decodes a reply.
sealed class TokenEvent {
  const TokenEvent();
}

/// A newly decoded piece of text, to be appended to the reply being streamed.
class TokenChunk extends TokenEvent {
  const TokenChunk(this.text);

  final String text;
}

/// The reply is complete.
class TokenDone extends TokenEvent {
  const TokenDone();
}

/// Generation stopped before completing.
class TokenFailure extends TokenEvent {
  const TokenFailure(this.message);

  final String message;
}

/// Decodes the raw [EventChannel] payloads sent by `StreamHandler.kt`.
class TokenStream {
  TokenStream(EventChannel channel)
      : _events = channel.receiveBroadcastStream().map(_decode);

  final Stream<TokenEvent> _events;

  Stream<TokenEvent> get events => _events;

  static TokenEvent _decode(Object? payload) {
    if (payload is! Map) {
      return const TokenFailure('Unexpected event from the AI engine.');
    }

    return switch (payload['type']) {
      'token' => TokenChunk(payload['text'] as String? ?? ''),
      'done' => const TokenDone(),
      'error' => TokenFailure(
          payload['message'] as String? ?? 'The AI engine stopped unexpectedly.',
        ),
      _ => const TokenFailure('Unexpected event from the AI engine.'),
    };
  }
}
