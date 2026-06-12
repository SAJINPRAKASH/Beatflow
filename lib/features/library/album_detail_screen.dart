import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/neumorphic_theme.dart';
import '../../services/database_service.dart';
import '../../services/audio_service.dart';
import '../../models/models.dart';

class AlbumDetailScreen extends ConsumerWidget {
  final String albumId;

  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final playerState = ref.watch(audioPlayerProvider);

    // Resolve playlist/album
    final playlist = db.playlists.firstWhere(
      (p) => p.id == albumId,
      orElse: () => db.playlists.first,
    );

    // Resolve tracks in this playlist
    final albumSongs = playlist.trackIds
        .map((id) => db.trackMetadata[id])
        .whereType<TrackModel>()
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Nav Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      context.pop();
                    },
                    child: NeumorphicBox(
                      shape: BoxShape.circle,
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.arrow_back, size: 22, color: AppTheme.textPrimary),
                    ),
                  ),
                  Text(
                    'Playlist Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  GestureDetector(
                    onTap: () {
                      context.go('/search');
                    },
                    child: NeumorphicBox(
                      shape: BoxShape.circle,
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.search, size: 22, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

            // Cover and stats (Static header)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildPlaylistCover(playlist, albumSongs),
                  const SizedBox(width: 20),
                  // Title & Metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Playlist • ${albumSongs.length} songs',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          playlist.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'BeatFlow Local Collection',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons: Play and Shuffle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  // Play
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (albumSongs.isNotEmpty) {
                          ref.read(audioPlayerProvider.notifier).playSong(albumSongs.first, albumSongs);
                        }
                      },
                      child: Container(
                        height: 46,
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
                            Icon(Icons.play_arrow, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Play All',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Shuffle
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (albumSongs.isNotEmpty) {
                          ref.read(audioPlayerProvider.notifier).toggleShuffle();
                          final rIndex = Random().nextInt(albumSongs.length);
                          ref.read(audioPlayerProvider.notifier).playSong(albumSongs[rIndex], albumSongs);
                        }
                      },
                      child: NeumorphicBox(
                        height: 46,
                        borderRadius: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shuffle, color: AppTheme.textPrimary, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Shuffle',
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Scrollable Tracklist with Reordering
            Expanded(
              child: albumSongs.isEmpty
                  ? Center(
                      child: Text(
                        'This playlist is empty.\nSearch and add songs to populate it!',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: albumSongs.length,
                      onReorder: (oldIndex, newIndex) {
                        ref.read(databaseProvider.notifier).reorderSongsInPlaylist(
                              playlist.id,
                              oldIndex,
                              newIndex,
                            );
                      },
                      itemBuilder: (context, index) {
                        final song = albumSongs[index];
                        final isPlayingThisSong = playerState.currentSong?.id == song.id;

                        return Padding(
                          key: ValueKey(song.id),
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: isPlayingThisSong
                                  ? Colors.black.withOpacity(0.04)
                                  : Colors.transparent,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Row(
                              children: [
                                // Reorder drag handle (on the left)
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Icon(
                                    Icons.drag_handle,
                                    color: AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Track Cover Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    song.thumbnail,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 40,
                                      height: 40,
                                      color: AppTheme.shadowDark,
                                      child: Icon(Icons.music_note, color: AppTheme.textSecondary, size: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Track Info
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      ref.read(audioPlayerProvider.notifier).playSong(song, albumSongs);
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isPlayingThisSong ? FontWeight.bold : FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${song.artist} • ${song.durationString}',
                                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Remove option
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_horiz, color: AppTheme.textSecondary, size: 20),
                                  color: AppTheme.background,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  onSelected: (value) {
                                    if (value == 'remove') {
                                      ref.read(databaseProvider.notifier).removeSongFromPlaylist(playlist.id, song.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Removed "${song.title}" from playlist')),
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, color: AppTheme.accentRed, size: 18),
                                          const SizedBox(width: 8),
                                          const Text('Remove', style: TextStyle(color: AppTheme.accentRed, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCover(PlaylistModel playlist, List<TrackModel> albumSongs) {
    String? coverUrl;
    if (albumSongs.isNotEmpty) {
      coverUrl = albumSongs.first.thumbnail;
    }

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(2, 6),
          ),
          const BoxShadow(
            color: Colors.white,
            blurRadius: 8,
            offset: Offset(-2, -2),
          ),
        ],
        color: AppTheme.shadowDark,
        image: coverUrl != null
            ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover)
            : null,
      ),
      child: coverUrl == null
          ? Icon(Icons.music_note, color: AppTheme.textSecondary, size: 36)
          : null,
    );
  }
}
