import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/neumorphic_theme.dart';
import '../../services/database_service.dart';
import '../../services/audio_service.dart';
import '../../models/models.dart';
import '../../services/download_service.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dbState = ref.watch(databaseProvider);
    final likedSongs = dbState.likedTracks;
    final historySongs = dbState.historyTracks;
    final downloadedSongs = dbState.downloadedTracks;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Screen Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text(
                    'Your Library',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),

            // Tab bar switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: NeumorphicBox(
                borderRadius: 16,
                style: NeumorphicStyle.pressed,
                height: 48,
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.background,
                    boxShadow: AppTheme.neumorphicShadowsFlatSoft,
                  ),
                  labelColor: AppTheme.textPrimary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'Liked'),
                    Tab(text: 'History'),
                    Tab(text: 'Downloads'),
                  ],
                ),
              ),
            ),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLikedTab(likedSongs),
                  _buildHistoryTab(historySongs),
                  _buildDownloadsTab(downloadedSongs, ref.read(databaseProvider.notifier)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikedTab(List<TrackModel> likedSongs) {
    if (likedSongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'No liked songs yet.\nHeart songs on the player to see them here!',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: likedSongs.length,
      itemBuilder: (context, index) {
        final song = likedSongs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GestureDetector(
            onTap: () {
              ref.read(audioPlayerProvider.notifier).playSong(song, likedSongs);
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
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 46,
                        height: 46,
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
                  IconButton(
                    icon: Icon(Icons.favorite, color: AppTheme.accentRed, size: 20),
                    onPressed: () {
                      ref.read(databaseProvider.notifier).toggleLikeSong(song.id);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(List<TrackModel> historySongs) {
    if (historySongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Listening history is empty.\nStart playing some music to see your history!',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: historySongs.length,
      itemBuilder: (context, index) {
        final song = historySongs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GestureDetector(
            onTap: () {
              ref.read(audioPlayerProvider.notifier).playSong(song, historySongs);
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
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 46,
                        height: 46,
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
                  Text(
                    song.durationString,
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadsTab(List<TrackModel> downloadedSongs, DatabaseNotifier dbNotifier) {
    final downloadTasks = ref.watch(downloadProvider).values
        .where((task) => task.status == 'downloading' || task.status == 'pending')
        .toList();

    if (downloadedSongs.isEmpty && downloadTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'No downloaded songs yet.\nDownload songs from the player options to play offline!',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        if (downloadTasks.isNotEmpty) ...[
          Text(
            'Active Downloads (${downloadTasks.length})',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 10),
          ...downloadTasks.map((task) {
            final progressPercent = (task.progress * 100).toStringAsFixed(0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: NeumorphicBox(
                borderRadius: 14,
                padding: const EdgeInsets.all(10),
                style: NeumorphicStyle.pressed,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        task.track.thumbnail,
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
                            task.track.title,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: task.progress,
                                  backgroundColor: AppTheme.shadowDark,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textPrimary),
                                  minHeight: 4,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$progressPercent%',
                                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                      onPressed: () {
                        ref.read(downloadProvider.notifier).cancelDownload(task.track.id);
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
        if (downloadedSongs.isNotEmpty) ...[
          if (downloadTasks.isNotEmpty) ...[
            Text(
              'Offline Downloads',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
          ],
          ...downloadedSongs.map((song) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GestureDetector(
                onTap: () {
                  ref.read(audioPlayerProvider.notifier).playSong(song, downloadedSongs);
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
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 46,
                            height: 46,
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
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: AppTheme.textSecondary, size: 20),
                        onPressed: () {
                          dbNotifier.deleteDownloadedTrack(song.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('"${song.title}" deleted from downloads.')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
