import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/neumorphic_theme.dart';
import '../../services/database_service.dart';
import '../../services/audio_service.dart';
import '../../services/youtube_service.dart';
import '../../models/models.dart';

class SmartRecommendationsScreen extends ConsumerStatefulWidget {
  final String? initialMood;

  const SmartRecommendationsScreen({super.key, this.initialMood});

  @override
  ConsumerState<SmartRecommendationsScreen> createState() => _SmartRecommendationsScreenState();
}

class _SmartRecommendationsScreenState extends ConsumerState<SmartRecommendationsScreen> with SingleTickerProviderStateMixin {
  late String _selectedMood;
  bool _isScanning = false;
  late AnimationController _radarController;
  List<TrackModel> _recommendedSongs = [];

  final List<Map<String, dynamic>> _moods = [
    {'name': 'Happy', 'emoji': '☀️', 'icon': Icons.wb_sunny, 'prompt': 'happy upbeat pop summer hits'},
    {'name': 'Sad', 'emoji': '🌧️', 'icon': Icons.umbrella, 'prompt': 'melancholy piano slow sad songs'},
    {'name': 'Workout', 'emoji': '⚡', 'icon': Icons.fitness_center, 'prompt': 'high energy gym workout training motivation music'},
    {'name': 'Study', 'emoji': '💻', 'icon': Icons.menu_book, 'prompt': 'lofi study beats chill instrumental focus'},
    {'name': 'Sleep', 'emoji': '🌙', 'icon': Icons.bedtime, 'prompt': 'relaxing deep sleep ambient atmosphere rain'},
    {'name': 'Driving', 'emoji': '🚗', 'icon': Icons.directions_car, 'prompt': 'road trip driving synthwave rock playlist'},
    {'name': 'Relax', 'emoji': '☕', 'icon': Icons.local_cafe, 'prompt': 'acoustic folk soft chill lounge relaxation'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedMood = widget.initialMood ?? 'Study';
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // If an initial mood is provided, automatically scan it
    if (widget.initialMood != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerMoodScan();
      });
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _triggerMoodScan() async {
    setState(() {
      _isScanning = true;
      _recommendedSongs = [];
    });
    _radarController.repeat();

    try {
      final moodData = _moods.firstWhere((m) => m['name'] == _selectedMood);
      final prompt = moodData['prompt'] as String;

      final youtubeService = ref.read(youtubeServiceProvider);
      final results = await youtubeService.searchTracks(prompt);

      // Save tracks metadata to local DB so we can reference them later
      final db = ref.read(databaseProvider.notifier);
      for (final track in results) {
        db.saveTrackMetadata(track);
      }

      if (mounted) {
        setState(() {
          _isScanning = false;
          _recommendedSongs = results;
        });
      }
    } catch (e) {
      print('Mood flow scan failed: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate mood playlist. Please try again.')),
        );
      }
    } finally {
      _radarController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Back Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: NeumorphicBox(
                      shape: BoxShape.circle,
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.arrow_back, size: 22, color: AppTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Vibe Flow',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isScanning 
                ? _buildScanningView()
                : _buildConfigAndResultsView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Generating Soundtrack...',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'Analyzing acoustic profiles for "$_selectedMood"',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 48),

        // Radar scanner visualizer
        AnimatedBuilder(
          animation: _radarController,
          builder: (context, child) {
            return Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accentDark.withOpacity(0.08),
                        width: 4,
                      ),
                    ),
                  ),
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accentDark.withOpacity(0.12),
                        width: 2,
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: _radarController.value * 2 * pi,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          center: Alignment.center,
                          colors: [
                            AppTheme.accentDark.withOpacity(0.35),
                            Colors.transparent,
                          ],
                          stops: const [0.15, 1.0],
                        ),
                      ),
                    ),
                  ),
                  NeumorphicBox(
                    width: 70,
                    height: 70,
                    shape: BoxShape.circle,
                    child: Icon(Icons.auto_awesome_motion, size: 30, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            );
          },
        ),
        
        const SizedBox(height: 48),
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textPrimary),
          strokeWidth: 2,
        ),
      ],
    );
  }

  Widget _buildConfigAndResultsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'How are you feeling right now? Select a mood and BeatFlow will build a live playlist matching your vibe.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
          ),

          // Mood List
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: _moods.length,
              itemBuilder: (context, index) {
                final mood = _moods[index];
                final name = mood['name'] as String;
                final emoji = mood['emoji'] as String;
                final icon = mood['icon'] as IconData;
                final isSelected = _selectedMood == name;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMood = name;
                    });
                  },
                  child: Container(
                    width: 90,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: NeumorphicBox(
                      style: isSelected ? NeumorphicStyle.pressed : NeumorphicStyle.flat,
                      borderRadius: 18,
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$name $emoji',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Scan Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: GestureDetector(
              onTap: _triggerMoodScan,
              child: Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.accentDark,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Scan Vibe & Create Playlist',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Scan Results
          if (_recommendedSongs.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vibe Station: $_selectedMood',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  IconButton(
                    icon: Icon(Icons.play_circle_fill, color: AppTheme.accentDark, size: 28),
                    onPressed: () {
                      ref.read(audioPlayerProvider.notifier).setQueue(_recommendedSongs, 0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Playing your $_selectedMood vibe flow!')),
                      );
                    },
                  ),
                ],
              ),
            ),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _recommendedSongs.length,
              itemBuilder: (context, index) {
                final song = _recommendedSongs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GestureDetector(
                    onTap: () {
                      ref.read(audioPlayerProvider.notifier).playSong(song, _recommendedSongs);
                    },
                    child: NeumorphicBox(
                      borderRadius: 14,
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              song.thumbnail,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 44,
                                height: 44,
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
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.artist,
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_right, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ] else ...[
            // Placeholder empty state
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.insights, size: 48, color: AppTheme.shadowDark),
                    const SizedBox(height: 12),
                    Text(
                      'Vibe Engine Standby',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    Text(
                      'Select a mood and scan to start listening',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
