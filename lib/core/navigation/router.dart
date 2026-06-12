import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/shared/app_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/library/album_detail_screen.dart';
import '../../features/playlists/playlists_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/credits_screen.dart';
import '../../features/settings/equalizer_screen.dart';
import '../../features/ai/ai_recommendations.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final goRouter = GoRouter(
  initialLocation: '/home',
  navigatorKey: _rootNavigatorKey,
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return AppShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SearchScreen(),
          ),
        ),
        GoRoute(
          path: '/library',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: LibraryScreen(),
          ),
        ),
        GoRoute(
          path: '/playlists',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: PlaylistsScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
        GoRoute(
          path: '/settings/credits',
          builder: (context, state) => const CreditsScreen(),
        ),
        GoRoute(
          path: '/settings/equalizer',
          builder: (context, state) => const EqualizerScreen(),
        ),
        GoRoute(
          path: '/album/:id',
          builder: (context, state) {
            final albumId = state.pathParameters['id'] ?? '';
            return AlbumDetailScreen(albumId: albumId);
          },
        ),
        GoRoute(
          path: '/mood-flow',
          builder: (context, state) {
            final mood = state.extra as String?;
            return SmartRecommendationsScreen(initialMood: mood);
          },
        ),
      ],
    ),
  ],
);
