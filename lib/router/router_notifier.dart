import 'dart:async';
import 'package:flutter/foundation.dart';
import '../auth/auth_bloc.dart';

class RouterNotifier extends ChangeNotifier {
  StreamSubscription<AuthState>? _subscription;

  RouterNotifier(AuthBloc authBloc) {
    _subscription = authBloc.stream.listen((state) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
