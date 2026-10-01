import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/credentials.dart';

class AuthState {
  const AuthState({this.isLoggedIn = false});

  final bool isLoggedIn;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  bool login(String username, String password) {
    final isValid =
        username == Credentials.username && password == Credentials.password;
    if (isValid) {
      state = const AuthState(isLoggedIn: true);
    }
    return isValid;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
