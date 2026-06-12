import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/neumorphic_theme.dart';
import '../player/mini_player.dart';
import '../player/player_screen.dart';

const _appChannel = MethodChannel('com.beatflow.beatflow/app');

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlayerExpanded = ref.watch(playerExpandedProvider);
    final routerState = GoRouterState.of(context);
    final location = routerState.matchedLocation;

    int selectedIndex = 0;
    if (location.startsWith('/search')) {
      selectedIndex = 1;
    } else if (location.startsWith('/library') || location.startsWith('/album')) {
      selectedIndex = 2;
    } else if (location.startsWith('/playlists')) {
      selectedIndex = 3;
    } else if (location.startsWith('/settings')) {
      selectedIndex = 4;
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
        } else {
          try {
            await _appChannel.invokeMethod('minimizeApp');
          } catch (e) {
            print('Error minimizing app: $e');
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Content Area + Bottom Nav Bar
          Column(
            children: [
              Expanded(child: child),
              // Mini Player sits right above bottom bar
              const MiniPlayer(),
              // Neumorphic Bottom Navigation Bar
              _buildBottomNavigationBar(context, selectedIndex),
            ],
          ),

          // Slide-up Now Playing full player
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            left: 0,
            right: 0,
            top: isPlayerExpanded ? 0 : MediaQuery.of(context).size.height,
            bottom: isPlayerExpanded ? 0 : -MediaQuery.of(context).size.height,
            child: const PlayerScreen(),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildBottomNavigationBar(BuildContext context, int selectedIndex) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, -6),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, Icons.home, 'Home', 0, selectedIndex, '/home'),
          _buildNavItem(context, Icons.search, 'Search', 1, selectedIndex, '/search'),
          _buildNavItem(context, Icons.library_music, 'Library', 2, selectedIndex, '/library'),
          _buildNavItem(context, Icons.queue_music, 'Playlists', 3, selectedIndex, '/playlists'),
          _buildNavItem(context, Icons.settings, 'Settings', 4, selectedIndex, '/settings'),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
    int selectedIndex,
    String route,
  ) {
    final isSelected = index == selectedIndex;
    return GestureDetector(
      onTap: () {
        context.go(route);
      },
      child: NeumorphicBox(
        style: isSelected ? NeumorphicStyle.pressed : NeumorphicStyle.flat,
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              size: 18,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
