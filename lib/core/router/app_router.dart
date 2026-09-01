import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/quota_guard.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/league/screens/league_screen.dart';
import '../../features/league/screens/create_league_screen.dart';
import '../../features/arena/screens/arena_screen.dart';
import '../../features/tasks/screens/task_list_screen.dart';
import '../../features/tasks/screens/create_task_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/stats/screens/stats_screen.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      // ⚠️ /league/create MUST be before /league/:leagueId
      // ?tab=1  →  opens directly on the "Join" tab
      GoRoute(
        path: '/league/create',
        name: 'create-league',
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return CreateLeagueScreen(initialTab: tab);
        },
      ),
      GoRoute(
        path: '/league/:leagueId',
        name: 'league',
        builder: (context, state) =>
            LeagueScreen(leagueId: state.pathParameters['leagueId']!),
        routes: [
          GoRoute(
            path: 'arena',
            name: 'arena',
            builder: (context, state) => ArenaScreen(
              leagueId: state.pathParameters['leagueId']!,
              initialTabIndex:
                  state.uri.queryParameters['tab'] == 'ranking' ? 2 : 0,
              rankingShowsPrevious:
                  state.uri.queryParameters['period'] == 'last',
            ),
          ),
          GoRoute(
            path: 'tasks',
            name: 'tasks',
            builder: (context, state) =>
                TaskListScreen(leagueId: state.pathParameters['leagueId']!),
            routes: [
              GoRoute(
                path: 'create',
                name: 'create-task',
                builder: (context, state) => CreateTaskScreen(
                    leagueId: state.pathParameters['leagueId']!),
              ),
            ],
          ),
          GoRoute(
            path: 'history',
            name: 'history',
            builder: (context, state) =>
                HistoryScreen(leagueId: state.pathParameters['leagueId']!),
          ),
          GoRoute(
            path: 'stats',
            name: 'stats',
            builder: (context, state) =>
                StatsScreen(leagueId: state.pathParameters['leagueId']!),
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
}
