import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/neumorphic_theme.dart';
import '../../services/database_service.dart';
import '../home/home_screen.dart' show MusicPreferencesDialog;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbState = ref.watch(databaseProvider);
    final isDark = dbState.theme == 'dark';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),

              // Theme Section
              _buildSectionTitle('Aesthetics & Theme'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: NeumorphicBox(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSettingRow(
                        context,
                        title: 'Dark Theme',
                        subtitle: 'Use darker colors to reduce eye strain',
                        icon: Icons.dark_mode,
                        trailing: Switch(
                          value: isDark,
                          activeColor: AppTheme.textPrimary,
                          onChanged: (val) {
                            ref.read(databaseProvider.notifier).changeTheme(val ? 'dark' : 'light');
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingRow(
                        context,
                        title: 'Low-Spec Optimization',
                        subtitle: 'Disable shadows for faster performance',
                        icon: Icons.bolt,
                        trailing: Switch(
                          value: dbState.lowSpecMode,
                          activeColor: AppTheme.textPrimary,
                          onChanged: (val) {
                            ref.read(databaseProvider.notifier).toggleLowSpecMode(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Audio Quality Section
              _buildSectionTitle('Audio Streaming'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: NeumorphicBox(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSettingRow(
                        context,
                        title: 'Streaming Quality',
                        subtitle: 'Current quality: ${dbState.audioQuality.toUpperCase()}',
                        icon: Icons.high_quality,
                        trailing: DropdownButton<String>(
                          value: dbState.audioQuality,
                          underline: const SizedBox.shrink(),
                          icon: Icon(Icons.arrow_drop_down, color: AppTheme.textPrimary),
                          dropdownColor: AppTheme.background,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              ref.read(databaseProvider.notifier).changeAudioQuality(newValue);
                            }
                          },
                          items: <String>['low', 'medium', 'high']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value.toUpperCase(),
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      Divider(color: AppTheme.shadowDark, height: 24),
                      GestureDetector(
                        onTap: () => context.push('/settings/equalizer'),
                        child: AbsorbPointer(
                          child: _buildSettingRow(
                            context,
                            title: 'Audio Equalizer',
                            subtitle: 'Custom presets and frequency curves',
                            icon: Icons.equalizer,
                            trailing: Icon(Icons.chevron_right, color: AppTheme.textPrimary),
                          ),
                        ),
                      ),
                      Divider(color: AppTheme.shadowDark, height: 24),
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => const MusicPreferencesDialog(isDismissible: true),
                          );
                        },
                        child: AbsorbPointer(
                          child: _buildSettingRow(
                            context,
                            title: 'Music Preferences',
                            subtitle: 'Favorite languages and artists',
                            icon: Icons.music_note,
                            trailing: Icon(Icons.chevron_right, color: AppTheme.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Storage & Cache Section
              _buildSectionTitle('Storage & Cache'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: NeumorphicBox(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSettingRow(
                        context,
                        title: 'Offline Downloads',
                        subtitle: 'Total downloaded: ${dbState.downloadedTrackIds.length} tracks',
                        icon: Icons.cloud_done,
                        trailing: Text(
                          'SAVED',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Divider(color: AppTheme.shadowDark, height: 24),
                      _buildSettingRow(
                        context,
                        title: 'Clear Listening History',
                        subtitle: 'Permanently deletes all recently played history',
                        icon: Icons.history,
                        trailing: TextButton(
                          onPressed: () {
                            ref.read(databaseProvider.notifier).clearHistory();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Listening history cleared!')),
                            );
                          },
                          child: TextStyle(
                            color: AppTheme.accentRed,
                            fontWeight: FontWeight.bold,
                          ).letText('Clear'),
                        ),
                      ),
                      Divider(color: AppTheme.shadowDark, height: 24),
                      _buildSettingRow(
                        context,
                        title: 'Clear Favorites',
                        subtitle: 'Removes all tracks from your liked songs',
                        icon: Icons.favorite_border,
                        trailing: TextButton(
                          onPressed: () {
                            ref.read(databaseProvider.notifier).clearFavorites();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Liked songs cleared!')),
                            );
                          },
                          child: TextStyle(
                            color: AppTheme.accentRed,
                            fontWeight: FontWeight.bold,
                          ).letText('Clear'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Credits Section
              _buildSectionTitle('Credits & Community'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => context.push('/settings/credits'),
                  child: NeumorphicBox(
                    borderRadius: 20,
                    padding: const EdgeInsets.all(16),
                    child: _buildSettingRow(
                      context,
                      title: 'Developers & Contributors',
                      subtitle: 'Meet the team behind BeatFlow',
                      icon: Icons.people_outline,
                      trailing: Icon(Icons.chevron_right, color: AppTheme.textPrimary),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // About Section
              Center(
                child: Column(
                  children: [
                    Text(
                      'BeatFlow Music Player',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'v2.0.0 – Premium Local Edition',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    NeumorphicBox(
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'No Accounts • No Ads • Pure Music',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget trailing,
  }) {
    return Row(
      children: [
        NeumorphicBox(
          shape: BoxShape.circle,
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppTheme.textPrimary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

extension _TextStyleHelper on TextStyle {
  Widget letText(String data) => Text(data, style: this);
}
