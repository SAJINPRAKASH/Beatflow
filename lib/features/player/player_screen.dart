import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/neumorphic_theme.dart';
import '../../models/models.dart';
import '../../services/audio_service.dart';
import '../../services/database_service.dart';
import '../../services/youtube_service.dart';
import '../../services/download_service.dart';
import 'mini_player.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  YoutubePlayerController? _ytController;
  bool _showVideo = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _ytController?.close();
    super.dispose();
  }

  void _initYoutube(String videoId) {
    _ytController?.close();
    _ytController = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: false,
        mute: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);
    final currentSong = playerState.currentSong;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final db = ref.watch(databaseProvider);
    final isLiked = db.likedTrackIds.contains(currentSong.id);
    final isLowSpec = db.lowSpecMode;

    // Control rotation animation based on playback and performance settings
    if (playerState.isPlaying && !_rotationController.isAnimating && !isLowSpec) {
      _rotationController.repeat();
    } else if ((!playerState.isPlaying || isLowSpec) && _rotationController.isAnimating) {
      _rotationController.stop();
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double albumArtSize = (constraints.maxHeight * 0.32).clamp(120.0, 260.0);
            return Stack(
              children: [
            Column(
              children: [
                // Top Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Chevron
                      GestureDetector(
                        onTap: () {
                          ref.read(playerExpandedProvider.notifier).state = false;
                        },
                        child: NeumorphicBox(
                          shape: BoxShape.circle,
                          padding: const EdgeInsets.all(10),
                          child: Icon(Icons.keyboard_arrow_down, size: 24, color: AppTheme.textPrimary),
                        ),
                      ),
                      Text(
                        'Now Playing',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      // Queue/List Menu
                      GestureDetector(
                        onTap: () {
                          _showQueueBottomSheet(context, ref, playerState);
                        },
                        child: NeumorphicBox(
                          shape: BoxShape.circle,
                          padding: const EdgeInsets.all(10),
                          child: Icon(Icons.playlist_play, size: 24, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Large Album Art Cover
                Center(
                  child: AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: isLowSpec ? 0.0 : _rotationController.value * 2 * pi,
                        child: child,
                      );
                    },
                    child: Container(
                      width: albumArtSize,
                      height: albumArtSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: isLowSpec ? null : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 22,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: AppTheme.shadowLight,
                            offset: const Offset(-6, -6),
                            blurRadius: 14,
                          ),
                          BoxShadow(
                            color: AppTheme.shadowDark,
                            offset: const Offset(6, 6),
                            blurRadius: 14,
                          ),
                        ],
                        border: isLowSpec ? Border.all(color: AppTheme.shadowDark, width: 2) : null,
                      ),
                      child: ClipOval(
                        child: Image.network(
                          currentSong.thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppTheme.shadowDark,
                            child: Icon(Icons.music_note, size: 80, color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Track Title & Artist Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Like button
                      GestureDetector(
                        onTap: () {
                          ref.read(databaseProvider.notifier).toggleLikeSong(currentSong.id);
                        },
                        child: NeumorphicBox(
                          shape: BoxShape.circle,
                          style: isLiked ? NeumorphicStyle.pressed : NeumorphicStyle.flat,
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? AppTheme.accentRed : AppTheme.textSecondary,
                            size: 18,
                          ),
                        ),
                      ),
                      
                      // Title & Artist
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              currentSong.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentSong.artist,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // More Options Button
                      GestureDetector(
                        onTap: () {
                          _showOptionsDialog(context, ref, currentSong);
                        },
                        child: NeumorphicBox(
                          shape: BoxShape.circle,
                          padding: const EdgeInsets.all(10),
                          child: Icon(Icons.more_horiz, size: 18, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Seek Bar Component
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: WaveformSeekBar(
                    position: playerState.position,
                    duration: playerState.duration,
                    onChangeEnd: (newPosition) {
                      ref.read(audioPlayerProvider.notifier).seek(newPosition);
                    },
                  ),
                ),

                // Time counters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(playerState.position),
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatDuration(playerState.duration),
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Playback Control Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Shuffle
                      GestureDetector(
                        onTap: () {
                          ref.read(audioPlayerProvider.notifier).toggleShuffle();
                        },
                        child: NeumorphicBox(
                          shape: BoxShape.circle,
                          style: playerState.isShuffleEnabled ? NeumorphicStyle.pressed : NeumorphicStyle.flat,
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.shuffle,
                            color: playerState.isShuffleEnabled ? AppTheme.textPrimary : AppTheme.textSecondary,
                            size: 16,
                          ),
                        ),
                      ),
                      // Skip Previous
                      GestureDetector(
                        onTap: () {
                          ref.read(audioPlayerProvider.notifier).previous();
                        },
                        child: NeumorphicBox(
                          shape: BoxShape.circle,
                          padding: const EdgeInsets.all(14),
                          child: Icon(
                            Icons.skip_previous,
                            color: AppTheme.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                      // Play / Pause
                      GestureDetector(
                        onTap: () {
                          ref.read(audioPlayerProvider.notifier).togglePlayPause();
                        },
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accentDark,
                            boxShadow: isLowSpec ? null : [
                              BoxShadow(
                                color: AppTheme.shadowDark,
                                offset: const Offset(4, 4),
                                blurRadius: 8,
                              ),
                              const BoxShadow(
                                color: Colors.white,
                                offset: Offset(-4, -4),
                                blurRadius: 8,
                              ),
                            ],
                            border: isLowSpec ? Border.all(color: Colors.white.withOpacity(0.5), width: 1.5) : null,
                          ),
                          child: Center(
                            child: Icon(
                              playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: AppTheme.isDark ? const Color(0xFF1E222B) : Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      // Skip Next
                      GestureDetector(
                        onTap: () {
                          ref.read(audioPlayerProvider.notifier).next();
                        },
                        child: NeumorphicBox(
                          shape: BoxShape.circle,
                          padding: const EdgeInsets.all(14),
                          child: Icon(
                            Icons.skip_next,
                            color: AppTheme.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                      // Repeat
                      GestureDetector(
                        onTap: () {
                          ref.read(audioPlayerProvider.notifier).toggleRepeat();
                        },
                        child: NeumorphicBox(
                          shape: BoxShape.circle,
                          style: playerState.repeatState != RepeatState.off
                              ? NeumorphicStyle.pressed
                              : NeumorphicStyle.flat,
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            playerState.repeatState == RepeatState.one ? Icons.repeat_one : Icons.repeat,
                            color: playerState.repeatState != RepeatState.off
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Watch Video Bar (YouTube Integration)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () {
                        _initYoutube(currentSong.id);
                        setState(() {
                          _showVideo = true;
                        });
                        ref.read(audioPlayerProvider.notifier).pause();
                      },
                      icon: const Icon(Icons.play_circle_fill, color: Colors.red, size: 22),
                      label: Text(
                        'Watch Official Music Video',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        backgroundColor: Colors.white.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Sliding YouTube Player Overlay
            if (_showVideo && _ytController != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.95),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Official Video Player',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 26),
                              onPressed: () {
                                _ytController?.close();
                                setState(() {
                                  _showVideo = false;
                                  _ytController = null;
                                });
                                ref.read(audioPlayerProvider.notifier).play();
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: YoutubePlayer(
                              controller: _ytController!,
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Streaming directly from YouTube. In compliance with developer policies, background streaming and audio extraction are disabled.',
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  void _showQueueBottomSheet(BuildContext context, WidgetRef ref, AudioPlayerState playerState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          height: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.shadowDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Up Next Queue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: playerState.queue.length,
                  itemBuilder: (context, index) {
                    final song = playerState.queue[index];
                    final isCurrent = index == playerState.currentIndex;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(song.thumbnail, width: 40, height: 40, fit: BoxFit.cover),
                      ),
                      title: Text(
                        song.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.artist,
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isCurrent
                          ? Icon(Icons.volume_up, color: AppTheme.textPrimary, size: 18)
                          : Text(song.durationString, style: const TextStyle(fontSize: 11)),
                      onTap: () {
                        ref.read(audioPlayerProvider.notifier).setQueue(playerState.queue, index);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOptionsDialog(BuildContext context, WidgetRef ref, TrackModel song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('Play Next'),
              onTap: () {
                Navigator.pop(context);
                ref.read(audioPlayerProvider.notifier).playNext(song);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${song.title}" will play next.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('Add to Queue'),
              onTap: () {
                Navigator.pop(context);
                ref.read(audioPlayerProvider.notifier).addToQueue(song);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${song.title}" added to queue.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to Playlist'),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylistDialog(context, ref, song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.equalizer),
              title: const Text('Equalizer Settings'),
              onTap: () {
                Navigator.pop(context);
                ref.read(playerExpandedProvider.notifier).state = false;
                context.push('/settings/equalizer');
              },
            ),
            Consumer(
              builder: (context, ref, _) {
                final liveDbState = ref.watch(databaseProvider);
                final liveIsDownloaded = liveDbState.downloadedTrackIds.contains(song.id);
                final liveDownloadState = ref.watch(downloadProvider);
                final liveDownloadTask = liveDownloadState[song.id];
                final liveIsDownloading = liveDownloadTask?.status == 'downloading';
                final progressPercent = ((liveDownloadTask?.progress ?? 0.0) * 100).toStringAsFixed(0);

                return ListTile(
                  leading: Icon(
                    liveIsDownloaded
                        ? Icons.cloud_done
                        : (liveIsDownloading ? Icons.sync : Icons.cloud_download),
                    color: AppTheme.textPrimary,
                  ),
                  title: Text(
                    liveIsDownloaded
                        ? 'Delete Download'
                        : (liveIsDownloading
                            ? 'Downloading ($progressPercent%)'
                            : 'Download Offline'),
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final db = ref.read(databaseProvider.notifier);
                    if (liveIsDownloaded) {
                      await db.deleteDownloadedTrack(song.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('"${song.title}" deleted from downloads.')),
                        );
                      }
                    } else if (liveIsDownloading) {
                      ref.read(downloadProvider.notifier).cancelDownload(song.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Download of "${song.title}" cancelled.')),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Downloading "${song.title}" offline...')),
                        );
                      }
                      try {
                        await ref.read(downloadProvider.notifier).startDownload(song);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('"${song.title}" downloaded successfully!')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to download "${song.title}": $e')),
                          );
                        }
                      }
                    }
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Song'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sharing link copied to clipboard!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, WidgetRef ref, TrackModel song) {
    final playlists = ref.read(databaseProvider).playlists;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Select Playlist'),
        content: playlists.isEmpty
            ? const Text('No custom playlists created. Create one in Playlists tab!')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ListTile(
                      leading: const Icon(Icons.queue_music),
                      title: Text(playlist.name),
                      onTap: () {
                        ref.read(databaseProvider.notifier).addSongToPlaylist(playlist.id, song);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added to ${playlist.name}!')),
                        );
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }
}

// Custom Waveform seekbar widget
class WaveformSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onChangeEnd;

  const WaveformSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onChangeEnd,
  });

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  double? _dragPercentage;
  
  final List<double> _barHeights = [
    0.2, 0.4, 0.3, 0.5, 0.7, 0.9, 0.8, 0.5, 0.3, 0.4,
    0.6, 0.8, 0.9, 0.7, 0.5, 0.4, 0.6, 0.8, 1.0, 0.9,
    0.7, 0.5, 0.6, 0.8, 0.7, 0.5, 0.3, 0.2, 0.4, 0.3,
    0.5, 0.7, 0.9, 0.7, 0.5, 0.4, 0.3, 0.5, 0.6, 0.4,
  ];

  @override
  Widget build(BuildContext context) {
    double progress = 0.0;
    if (widget.duration.inMilliseconds > 0) {
      progress = widget.position.inMilliseconds / widget.duration.inMilliseconds;
    }
    progress = progress.clamp(0.0, 1.0);

    final activePercentage = _dragPercentage ?? progress;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barCount = _barHeights.length;
        final totalWidth = constraints.maxWidth;
        final barSpacing = 3.0;
        final barWidth = (totalWidth - (barSpacing * (barCount - 1))) / barCount;

        return GestureDetector(
          onHorizontalDragStart: (details) {
            _updatePosition(details.localPosition.dx, totalWidth);
          },
          onHorizontalDragUpdate: (details) {
            _updatePosition(details.localPosition.dx, totalWidth);
          },
          onHorizontalDragEnd: (details) {
            if (_dragPercentage != null) {
              final newMs = (_dragPercentage! * widget.duration.inMilliseconds).round();
              widget.onChangeEnd(Duration(milliseconds: newMs));
              setState(() {
                _dragPercentage = null;
              });
            }
          },
          onTapDown: (details) {
            final dragPct = (details.localPosition.dx / totalWidth).clamp(0.0, 1.0);
            final newMs = (dragPct * widget.duration.inMilliseconds).round();
            widget.onChangeEnd(Duration(milliseconds: newMs));
          },
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(barCount, (index) {
                final barRatio = index / barCount;
                final isActive = barRatio <= activePercentage;
                final heightFactor = _barHeights[index];

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: barWidth,
                  height: 36 * heightFactor,
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.textPrimary : AppTheme.shadowDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  void _updatePosition(double localX, double totalWidth) {
    setState(() {
      _dragPercentage = (localX / totalWidth).clamp(0.0, 1.0);
    });
  }
}
