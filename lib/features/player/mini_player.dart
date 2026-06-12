import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/neumorphic_theme.dart';
import '../../services/audio_service.dart';
import '../../services/database_service.dart';

// Provider to control the full screen expansion of the player
final playerExpandedProvider = StateProvider<bool>((ref) => false);

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);
    final currentSong = playerState.currentSong;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final db = ref.watch(databaseProvider);
    final isLiked = db.likedTrackIds.contains(currentSong.id);
    
    // Calculate progress ratio
    double progress = 0.0;
    if (playerState.duration.inMilliseconds > 0) {
      progress = playerState.position.inMilliseconds / playerState.duration.inMilliseconds;
    }
    progress = progress.clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        ref.read(playerExpandedProvider.notifier).state = true;
      },
      child: Container(
        height: 72,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: NeumorphicBox(
          borderRadius: 20,
          backgroundColor: AppTheme.background,
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Album Art
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        image: DecorationImage(
                          image: NetworkImage(currentSong.thumbnail),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Track Title & Artist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            currentSong.title,
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
                            currentSong.artist,
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
                    // Like/Favorite Button
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? AppTheme.accentRed : AppTheme.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        ref.read(databaseProvider.notifier).toggleLikeSong(currentSong.id);
                      },
                    ),
                    // Skip Previous Button
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous,
                        color: AppTheme.textPrimary,
                        size: 22,
                      ),
                      onPressed: () {
                        ref.read(audioPlayerProvider.notifier).previous();
                      },
                    ),
                    // Play / Pause Button
                    IconButton(
                      icon: playerState.isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textPrimary),
                              ),
                            )
                          : Icon(
                              playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: AppTheme.textPrimary,
                              size: 24,
                            ),
                      onPressed: () {
                        ref.read(audioPlayerProvider.notifier).togglePlayPause();
                      },
                    ),
                    // Skip Next Button
                    IconButton(
                      icon: Icon(
                        Icons.skip_next,
                        color: AppTheme.textPrimary,
                        size: 22,
                      ),
                      onPressed: () {
                        ref.read(audioPlayerProvider.notifier).next();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Mini progress bar line at the bottom
              Container(
                height: 3,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.shadowDark,
                  borderRadius: BorderRadius.circular(1.5),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.textPrimary,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
