import 'package:flutter/foundation.dart';

import '../../../../core/ai_bridge/native_ai_bridge.dart';

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.isStreaming = false,
  });

  final int id;
  final AiRole role;
  final String text;

  /// True while the engine is still appending to this reply.
  final bool isStreaming;

  bool get isUser => role == AiRole.user;

  ChatMessage copyWith({String? text, bool? isStreaming}) => ChatMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        isStreaming: isStreaming ?? this.isStreaming,
      );

  AiTurn toTurn() => AiTurn(role: role, text: text);
}
