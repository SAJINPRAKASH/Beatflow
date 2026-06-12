import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import '../../core/theme/neumorphic_theme.dart';
import '../../services/database_service.dart';
import '../../services/audio_service.dart';
import '../../services/youtube_service.dart';
import '../../models/models.dart';

// Providers for home screen data
final homeTrendingProvider = FutureProvider.autoDispose<List<TrackModel>>((ref) async {
  return ref.watch(youtubeServiceProvider).getTrendingTracks();
});

final homeNewReleasesProvider = FutureProvider.autoDispose<List<TrackModel>>((ref) async {
  return ref.watch(youtubeServiceProvider).getNewReleases();
});

final homeRecommendationsProvider = FutureProvider.autoDispose<List<TrackModel>>((ref) async {
  final history = ref.watch(databaseProvider).listeningHistory;
  return ref.watch(youtubeServiceProvider).getRecommendations(history);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboarding();
    });
  }

  void _checkOnboarding() {
    final settingsBox = Hive.isBoxOpen('beatflow_settings') ? Hive.box('beatflow_settings') : null;
    final onboarded = settingsBox?.get('preferences_onboarded', defaultValue: false) as bool? ?? false;
    if (!onboarded && mounted) {
      _showPreferencesDialog();
    }
  }

  void _showPreferencesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const MusicPreferencesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dbState = ref.watch(databaseProvider);
    final historyTracks = dbState.historyTracks;

    final trendingAsync = ref.watch(homeTrendingProvider);
    final newReleasesAsync = ref.watch(homeNewReleasesProvider);
    final recommendedAsync = ref.watch(homeRecommendationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.textPrimary,
          backgroundColor: AppTheme.background,
          onRefresh: () async {
            ref.invalidate(homeTrendingProvider);
            ref.invalidate(homeNewReleasesProvider);
            ref.invalidate(homeRecommendationsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BeatFlow',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.8,
                            ),
                          ),
                          Text(
                            'Instant Music Discovery',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Mood Stations
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    'Mood Stations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                SizedBox(
                  height: 96,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      _buildMoodCard(context, 'Happy ☀️', 'Happy'),
                      _buildMoodCard(context, 'Sad 🌧️', 'Sad'),
                      _buildMoodCard(context, 'Workout ⚡', 'Workout'),
                      _buildMoodCard(context, 'Study 💻', 'Study'),
                      _buildMoodCard(context, 'Sleep 🌙', 'Sleep'),
                      _buildMoodCard(context, 'Driving 🚗', 'Driving'),
                      _buildMoodCard(context, 'Relax ☕', 'Relax'),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Recently Played Section (Only visible if history contains items)
                if (historyTracks.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'Recently Played',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 164,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      scrollDirection: Axis.horizontal,
                      itemCount: historyTracks.length,
                      itemBuilder: (context, index) {
                        final song = historyTracks[index];
                        return _buildHorizontalTrackCard(song, historyTracks);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Trending Music Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Trending Music',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                trendingAsync.when(
                  data: (tracks) => SizedBox(
                    height: 164,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      scrollDirection: Axis.horizontal,
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        final song = tracks[index];
                        return _buildHorizontalTrackCard(song, tracks);
                      },
                    ),
                  ),
                  loading: () => SizedBox(
                    height: 164,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary),
                    ),
                  ),
                  error: (err, stack) => SizedBox(
                    height: 100,
                    child: Center(
                      child: Text('Unable to load trending tracks', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Recommended Tracks Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Recommended Tracks',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                recommendedAsync.when(
                  data: (tracks) => _buildVerticalTrackList(tracks),
                  loading: () => Padding(
                    padding: const EdgeInsets.all(36.0),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary),
                    ),
                  ),
                  error: (err, stack) => Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text('Add tracks to history to see recommendations', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // New Releases Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'New Releases',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                newReleasesAsync.when(
                  data: (tracks) => _buildVerticalTrackList(tracks.take(6).toList()),
                  loading: () => Padding(
                    padding: const EdgeInsets.all(36.0),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary),
                    ),
                  ),
                  error: (err, stack) => Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text('Unable to load new releases', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoodCard(BuildContext context, String title, String moodName) {
    return GestureDetector(
      onTap: () {
        context.push('/mood-flow', extra: moodName);
      },
      child: Container(
        width: 112,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: NeumorphicBox(
          borderRadius: 16,
          backgroundColor: AppTheme.background,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalTrackCard(TrackModel song, List<TrackModel> queue) {
    return GestureDetector(
      onTap: () {
        ref.read(audioPlayerProvider.notifier).playSong(song, queue);
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NeumorphicBox(
              borderRadius: 16,
              padding: EdgeInsets.zero,
              width: 120,
              height: 108,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  song.thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppTheme.shadowDark,
                    child: Icon(Icons.music_note, color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Text(
                song.title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Text(
                song.artist,
                style: TextStyle(
                  fontSize: 9,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalTrackList(List<TrackModel> tracks) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final song = tracks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GestureDetector(
            onTap: () {
              ref.read(audioPlayerProvider.notifier).playSong(song, tracks);
            },
            child: NeumorphicBox(
              borderRadius: 16,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      song.thumbnail,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 48,
                        height: 48,
                        color: AppTheme.shadowDark,
                        child: Icon(Icons.music_note, color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.play_circle_outline, color: AppTheme.textPrimary, size: 22),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class MusicPreferencesDialog extends StatefulWidget {
  final bool isDismissible;
  const MusicPreferencesDialog({super.key, this.isDismissible = false});

  @override
  State<MusicPreferencesDialog> createState() => _MusicPreferencesDialogState();
}

class _MusicPreferencesDialogState extends State<MusicPreferencesDialog> {
  final List<String> _languages = [
    'Hindi', 'English', 'Malayalam', 'Tamil', 'Telugu', 'Punjabi', 'Kannada', 'Bengali', 'Marathi'
  ];

  final List<String> _artists = [
    'Arijit Singh', 'A.R. Rahman', 'Shreya Ghoshal', 'Sid Sriram', 
    'K.S. Chithra', 'S.P. Balasubrahmanyam', 'Diljit Dosanjh', 
    'Anirudh Ravichander', 'Taylor Swift', 'Ed Sheeran', 'Billie Eilish'
  ];

  final List<String> _selectedLanguages = [];
  final List<String> _selectedArtists = [];

  @override
  void initState() {
    super.initState();
    final settingsBox = Hive.isBoxOpen('beatflow_settings') ? Hive.box('beatflow_settings') : null;
    final List<dynamic>? savedLangs = settingsBox?.get('fav_languages');
    final List<dynamic>? savedArtists = settingsBox?.get('fav_artists');
    if (savedLangs != null) {
      _selectedLanguages.addAll(List<String>.from(savedLangs));
    }
    if (savedArtists != null) {
      _selectedArtists.addAll(List<String>.from(savedArtists));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Music Preferences',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              if (widget.isDismissible)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select your favorite languages and artists to customize your recommended feed.',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Languages',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _languages.map((lang) {
                  final isSelected = _selectedLanguages.contains(lang);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedLanguages.remove(lang);
                        } else {
                          _selectedLanguages.add(lang);
                        }
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected ? null : AppTheme.neumorphicShadowsFlatSoft,
                      ),
                      child: NeumorphicBox(
                        style: isSelected ? NeumorphicStyle.pressed : NeumorphicStyle.flat,
                        borderRadius: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          lang,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              Text(
                'Favorite Artists',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _artists.map((artist) {
                  final isSelected = _selectedArtists.contains(artist);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedArtists.remove(artist);
                        } else {
                          _selectedArtists.add(artist);
                        }
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected ? null : AppTheme.neumorphicShadowsFlatSoft,
                      ),
                      child: NeumorphicBox(
                        style: isSelected ? NeumorphicStyle.pressed : NeumorphicStyle.flat,
                        borderRadius: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          artist,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      actions: [
        Consumer(
          builder: (context, ref, _) => GestureDetector(
            onTap: () async {
              final settingsBox = Hive.isBoxOpen('beatflow_settings') ? Hive.box('beatflow_settings') : null;
              if (settingsBox != null) {
                await settingsBox.put('fav_languages', _selectedLanguages);
                await settingsBox.put('fav_artists', _selectedArtists);
                await settingsBox.put('preferences_onboarded', true);
              }
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preferences saved! Refreshing feed...')),
                );
              }
              ref.invalidate(homeRecommendationsProvider);
            },
            child: Container(
              height: 48,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.accentDark,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Save Preferences',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
