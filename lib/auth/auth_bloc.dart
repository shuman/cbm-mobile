import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/auth_service.dart';
import '../utils/storage_util.dart';

// Events
abstract class AuthEvent {}

class CheckAuthStatusEvent extends AuthEvent {}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;

  LoginEvent({required this.email, required this.password});
}

class LogoutEvent extends AuthEvent {}

// States
abstract class AuthState {}

class AuthLoadingState extends AuthState {}

class AuthAuthenticatedState extends AuthState {
  final String token;
  final Map<String, dynamic>? user;
  AuthAuthenticatedState(this.token, {this.user});
}

class AuthUnauthenticatedState extends AuthState {}

class AuthErrorState extends AuthState {
  final String message;
  AuthErrorState(this.message);
}

class Auth2FARequiredState extends AuthState {
  final String twoFaToken;
  final String message;
  Auth2FARequiredState(this.twoFaToken, this.message);
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService authService;

  AuthBloc({required this.authService}) : super(AuthLoadingState()) {
    on<CheckAuthStatusEvent>(_checkAuthStatus);
    on<LoginEvent>(_login);
    on<LogoutEvent>(_logout);
  }

  Future<void> _checkAuthStatus(
      CheckAuthStatusEvent event, Emitter<AuthState> emit) async {
    if (kDebugMode) debugPrint('[AuthBloc] CheckAuthStatus');
    emit(AuthLoadingState());
    final token = await StorageUtil.getToken();
    if (kDebugMode) debugPrint('[AuthBloc] Token: ${token != null ? "exists" : "null"}');
    if (token != null && token.isNotEmpty) {
      final user = await StorageUtil.getUser();
      emit(AuthAuthenticatedState(token, user: user));
      if (kDebugMode) debugPrint('[AuthBloc] -> Authenticated');
    } else {
      emit(AuthUnauthenticatedState());
      if (kDebugMode) debugPrint('[AuthBloc] -> Unauthenticated');
    }
  }

  Future<void> _login(LoginEvent event, Emitter<AuthState> emit) async {
    if (kDebugMode) debugPrint('[AuthBloc] Login started');
    emit(AuthLoadingState());
    try {
      final result = await AuthService.login(event.email, event.password);
      if (kDebugMode) debugPrint('[AuthBloc] Login result: ${result.keys.join(", ")}');
      
      if (result['requires_2fa'] == true) {
        emit(Auth2FARequiredState(
          result['two_fa_token'],
          result['message'] ?? 'Two-factor authentication required',
        ));
        return;
      }
      
      if (result['success'] == true && result['token'] != null) {
        emit(AuthAuthenticatedState(result['token'], user: result['user']));
      } else {
        emit(AuthErrorState(result['error'] ?? 'Login failed'));
      }
    } catch (e) {
      emit(AuthErrorState('Login failed: ${e.toString()}'));
    }
  }

  Future<void> _logout(LogoutEvent event, Emitter<AuthState> emit) async {
    await StorageUtil.clearAll();
    emit(AuthUnauthenticatedState());
  }
}
