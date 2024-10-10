import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/deposit_screen.dart';
import 'screens/deposit_add_screen.dart';
import 'screens/expense_screen.dart';
import 'auth/auth_bloc.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AuthBloc(authService: AuthService())..add(CheckAuthStatusEvent()),
      child: MaterialApp(
        title: 'Admin Portal',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthLoadingState) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is AuthAuthenticatedState) {
              return const HomeScreen();
            } else if (state is AuthUnauthenticatedState) {
              return LoginScreen();
            } else if (state is AuthErrorState) {
              return Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: Center(child: Text(state.message)),
              );
            } else {
              return const CircularProgressIndicator(); // Fallback state
            }
          },
        ),
        routes: {
          '/login': (context) => LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/deposit': (context) => const DepositScreen(),
          '/deposit_add': (context) => const DepositAddScreen(),
          '/expense': (context) => const ExpenseScreen(),
        },
      ),
    );
  }
}
