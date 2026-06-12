import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/neumorphic_theme.dart';
import '../../services/database_service.dart';
import '../../models/models.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('New Playlist', style: TextStyle(fontWeight: FontWeight.bold)),
        content: NeumorphicBox(
          style: NeumorphicStyle.pressed,
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter playlist name...',
              border: InputBorder.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = titleController.text.trim();
              if (name.isNotEmpty) {
                ref.read(databaseProvider.notifier).createPlaylist(name);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Playlist "$name" created!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRenamePlaylistDialog(BuildContext context, WidgetRef ref, PlaylistModel playlist) {
    final titleController = TextEditingController(text: playlist.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Rename Playlist', style: TextStyle(fontWeight: FontWeight.bold)),
        content: NeumorphicBox(
          style: NeumorphicStyle.pressed,
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter new name...',
              border: InputBorder.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = titleController.text.trim();
              if (newName.isNotEmpty && newName != playlist.name) {
                ref.read(databaseProvider.notifier).renamePlaylist(playlist.id, newName);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Playlist renamed to "$newName"')),
                );
              } else {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref, PlaylistModel playlist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Playlist', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${playlist.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(databaseProvider.notifier).deletePlaylist(playlist.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Playlist "${playlist.name}" deleted')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbState = ref.watch(databaseProvider);
    final playlists = dbState.playlists;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Screen Header + Add Playlist Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Playlists',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  GestureDetector(
                    onTap: () => _showCreatePlaylistDialog(context, ref),
                    child: NeumorphicBox(
                      shape: BoxShape.circle,
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.add, color: AppTheme.textPrimary, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // Playlists List
            Expanded(
              child: playlists.isEmpty
                  ? _buildEmptyState(context, ref)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: GestureDetector(
                            onTap: () {
                              context.push('/album/${playlist.id}');
                            },
                            child: NeumorphicBox(
                              borderRadius: 20,
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Playlist cover placeholder or derived
                                  _buildPlaylistCover(playlist, dbState),
                                  const SizedBox(width: 16),
                                  // Playlist Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          playlist.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${playlist.trackIds.length} Songs',
                                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Action menu
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, color: AppTheme.textSecondary),
                                    color: AppTheme.background,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    onSelected: (value) {
                                      if (value == 'rename') {
                                        _showRenamePlaylistDialog(context, ref, playlist);
                                      } else if (value == 'delete') {
                                        _showDeleteConfirmDialog(context, ref, playlist);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      PopupMenuItem(
                                        value: 'rename',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 18, color: AppTheme.textPrimary),
                                            const SizedBox(width: 10),
                                            Text('Rename', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.delete, size: 18, color: AppTheme.accentRed),
                                            const SizedBox(width: 10),
                                            Text('Delete', style: TextStyle(fontSize: 13, color: AppTheme.accentRed)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_music, size: 64, color: AppTheme.shadowDark),
          const SizedBox(height: 16),
          Text(
            'No playlists yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a playlist and add songs to start your collection',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _showCreatePlaylistDialog(context, ref),
            child: NeumorphicBox(
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                'Create Playlist',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCover(PlaylistModel playlist, DatabaseState dbState) {
    // If playlist has songs, try to use the first song's cover art as playlist cover
    String? coverUrl;
    if (playlist.trackIds.isNotEmpty) {
      final track = dbState.trackMetadata[playlist.trackIds.first];
      if (track != null) {
        coverUrl = track.thumbnail;
      }
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.shadowDark,
        image: coverUrl != null
            ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover)
            : null,
      ),
      child: coverUrl == null
          ? Icon(Icons.music_note, color: AppTheme.textSecondary, size: 24)
          : null,
    );
  }
}
