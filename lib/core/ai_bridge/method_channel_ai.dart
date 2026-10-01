import 'dart:io';

import 'package:flutter/services.dart';

import 'native_ai_bridge.dart';
import 'token_stream.dart';

/// Talks to the LiteRT-LM engine hosted by `MainActivity.kt` and `AppDelegate.swift`.
class MethodChannelAi implements NativeAiBridge {
  MethodChannelAi() : _tokens = TokenStream(const EventChannel(_tokenChannel));

  static const _methodChannel = MethodChannel('com.lumin.ai/litert_lm');
  static const _tokenChannel = 'com.lumin.ai/litert_lm/tokens';

  final TokenStream _tokens;

  @override
  Stream<TokenEvent> get tokens {
    _ensureSupported();
    return _tokens.events;
  }

  @override
  Future<void> loadModel() {
    _ensureSupported();
    return _methodChannel.invokeMethod<void>('loadModel');
  }

  @override
  Future<void> sendMessage({
    required String text,
    required List<AiTurn> history,
    required bool resetContext,
  }) {
    _ensureSupported();
    return _methodChannel.invokeMethod<void>('sendMessage', {
      'text': text,
      'resetContext': resetContext,
      'history': [
        for (final turn in history) {'role': turn.role.name, 'text': turn.text},
      ],
    });
  }

  @override
  Future<void> cancel() {
    _ensureSupported();
    return _methodChannel.invokeMethod<void>('cancel');
  }

  void _ensureSupported() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError(
        'On-device AI is only implemented for Android and iOS.',
      );
    }
  }
}
