import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';

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
  AuthAuthenticatedState(this.token);
}

class AuthUnauthenticatedState extends AuthState {}

class AuthErrorState extends AuthState {
  final String message;
  AuthErrorState(this.message);
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService authService;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  AuthBloc({required this.authService}) : super(AuthLoadingState()) {
    on<CheckAuthStatusEvent>(_checkAuthStatus);
    on<LoginEvent>(_login);
    on<LogoutEvent>(_logout);
  }

  Future<void> _checkAuthStatus(
      CheckAuthStatusEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    final token = await secureStorage.read(key: 'auth_token');
    if (token != null) {
      emit(AuthAuthenticatedState(token));
    } else {
      emit(AuthUnauthenticatedState());
    }
  }

  Future<void> _login(LoginEvent event, Emitter<AuthState> emit) async {
  emit(AuthLoadingState());
  try {
    // Access static method using AuthService directly
    final token = await AuthService.login(event.email, event.password);
    if (token != '') {
      await secureStorage.write(key: 'auth_token', value: token);
      emit(AuthAuthenticatedState(token));
    } else {
      emit(AuthUnauthenticatedState());
    }
  } catch (e) {
    emit(AuthErrorState('Login failed: ${e.toString()}'));
  }
}

  Future<void> _logout(LogoutEvent event, Emitter<AuthState> emit) async {
    await secureStorage.delete(key: 'auth_token');
    emit(AuthUnauthenticatedState());
  }
}
