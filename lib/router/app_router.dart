import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../screens/login_screen.dart';
import '../screens/project_selection_screen.dart';
import '../screens/home_screen.dart';
import '../screens/messaging_screen.dart';
import '../screens/channel_detail_screen.dart';
import '../screens/direct_conversation_screen.dart';
import '../screens/decisions_screen.dart';
import '../screens/decision_detail_screen.dart';
import '../screens/notices_screen.dart';
import '../screens/files_screen.dart';
import '../screens/members_screen.dart';
import '../screens/deposit_screen.dart';
import '../screens/deposit_add_screen.dart';
import '../screens/expense_screen.dart';
import '../screens/expense_add_screen.dart';
import '../utils/storage_util.dart';
import 'router_notifier.dart';
import '../messaging/message_bloc.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static Future<bool> _isAuthenticated() async {
    final token = await StorageUtil.getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<bool> _hasProject() async {
    final projectId = await StorageUtil.getProjectId();
    return projectId != null && projectId.isNotEmpty;
  }

  static GoRouter createRouter(RouterNotifier routerNotifier) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/login',
      refreshListenable: routerNotifier,
      redirect: (BuildContext context, GoRouterState state) async {
      final isAuth = await _isAuthenticated();
      final hasProject = await _hasProject();
      final currentPath = state.matchedLocation;

      if (kDebugMode) {
        debugPrint('[Router] Redirect check: path=$currentPath, auth=$isAuth, project=$hasProject');
      }

      if (!isAuth && currentPath != '/login') {
        if (kDebugMode) debugPrint('[Router] Not authenticated, redirect to /login');
        return '/login';
      }

      if (isAuth && currentPath == '/login') {
        final target = hasProject ? '/home' : '/project-selection';
        if (kDebugMode) debugPrint('[Router] Authenticated at /login, redirect to $target');
        return target;
      }

      if (isAuth && !hasProject && currentPath != '/project-selection') {
        if (kDebugMode) debugPrint('[Router] No project, redirect to /project-selection');
        return '/project-selection';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/project-selection',
        builder: (context, state) => const ProjectSelectionScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/messaging',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MessagingScreen(),
            ),
          ),
          GoRoute(
            path: '/channel/:channelId',
            builder: (context, state) {
              final channelId = state.pathParameters['channelId']!;
              final extra = state.extra as Map<String, dynamic>?;
              final channelName = extra?['channelName']?.toString() ?? 'Channel';

              return BlocProvider(
                create: (context) => MessageBloc(),
                child: ChannelDetailScreen(
                  channelId: channelId,
                  channelName: channelName,
                ),
              );
            },
          ),
          GoRoute(
            path: '/direct/:conversationId',
            builder: (context, state) {
              final conversationId = state.pathParameters['conversationId']!;
              final extra = state.extra as Map<String, dynamic>?;
              final recipientName = extra?['recipientName']?.toString() ?? 'User';

              return BlocProvider(
                create: (context) => MessageBloc(),
                child: DirectConversationScreen(
                  conversationId: conversationId,
                  recipientName: recipientName,
                ),
              );
            },
          ),
          GoRoute(
            path: '/decisions',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DecisionsScreen(),
            ),
            routes: [
              GoRoute(
                path: ':decisionId',
                builder: (context, state) {
                  final decisionId = state.pathParameters['decisionId']!;
                  final extra = state.extra as Map<String, dynamic>?;
                  final title = extra?['title']?.toString() ?? 'Discussion';

                  return DecisionDetailScreen(
                    decisionId: decisionId,
                    title: title,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/notices',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: NoticesScreen(),
            ),
          ),
          GoRoute(
            path: '/files',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FilesScreen(),
            ),
          ),
          GoRoute(
            path: '/members',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MembersScreen(),
            ),
          ),
          GoRoute(
            path: '/deposits',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DepositScreen(),
            ),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const DepositAddScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/expenses',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ExpenseScreen(),
            ),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const ExpenseAddScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    );
  }
}
