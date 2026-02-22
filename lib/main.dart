import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'auth/auth_bloc.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/message_notification_manager.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'router/router_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await NotificationService().initialize();
  await NotificationService().requestPermissions();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthBloc _authBloc;
  late final RouterNotifier _routerNotifier;
  late final GoRouter _router;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(authService: AuthService())..add(CheckAuthStatusEvent());
    _routerNotifier = RouterNotifier(_authBloc);
    _router = AppRouter.createRouter(_routerNotifier);

    _authSubscription = _authBloc.stream.listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(AuthState state) {
    if (state is AuthAuthenticatedState) {
      MessageNotificationManager().start();
    } else if (state is AuthUnauthenticatedState) {
      MessageNotificationManager().stop();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    MessageNotificationManager().stop();
    _routerNotifier.dispose();
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'CoBuild Manager',
        theme: AppTheme.theme,
        routerConfig: _router,
      ),
    );
  }
}
