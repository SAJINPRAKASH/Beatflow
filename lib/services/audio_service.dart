import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'youtube_service.dart';

late AudioHandler audioHandler;

class BeatFlowAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  late final AudioPlayer player;
  AndroidEqualizer? equalizer;
  VoidCallback? onSkipToNext;
  VoidCallback? onSkipToPrevious;

  BeatFlowAudioHandler() {
    if (!kIsWeb && Platform.isAndroid) {
      equalizer = AndroidEqualizer();
      player = AudioPlayer(
        audioPipeline: AudioPipeline(
          androidAudioEffects: [equalizer!],
        ),
      );
    } else {
      player = AudioPlayer();
    }
    player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState] ?? AudioProcessingState.idle,
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> stop() => player.stop();

  @override
  Future<void> skipToNext() async {
    onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPrevious?.call();
  }

  void updateMediaItemFromTrack(TrackModel song) {
    final item = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artUri: Uri.parse(song.thumbnail),
    );
    mediaItem.add(item);
    queue.add([item]);
  }
}

enum RepeatState {
  off,
  all,
  one,
}

class AudioPlayerState {
  final TrackModel? currentSong;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final bool isShuffleEnabled;
  final RepeatState repeatState;
  final List<TrackModel> queue;
  final int currentIndex;

  AudioPlayerState({
    this.currentSong,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.isShuffleEnabled = false,
    this.repeatState = RepeatState.off,
    this.queue = const [],
    this.currentIndex = -1,
  });

  AudioPlayerState copyWith({
    TrackModel? Function()? currentSong,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    bool? isShuffleEnabled,
    RepeatState? repeatState,
    List<TrackModel>? queue,
    int? currentIndex,
  }) {
    return AudioPlayerState(
      currentSong: currentSong != null ? currentSong() : this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      repeatState: repeatState ?? this.repeatState,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  final Ref _ref;
  AudioPlayer get _player => (audioHandler as BeatFlowAudioHandler).player;
  
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _bufferedSubscription;

  AudioPlayerNotifier(this._ref) : super(AudioPlayerState()) {
    _init();
  }

  Future<void> _init() async {
    // Register skip callbacks in handler
    final handler = audioHandler as BeatFlowAudioHandler;
    handler.onSkipToNext = () => next();
    handler.onSkipToPrevious = () => previous();
    // Setup background audio session
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      print('Error configuring audio session: $e');
    }

    // Listen to playback state (playing, finished, buffering)
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      final isPlaying = state.playing;
      final processingState = state.processingState;

      bool isLoading = false;
      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        isLoading = true;
      }

      // Automatically play next song when completed
      if (processingState == ProcessingState.completed) {
        _handleSongCompletion();
      }

      this.state = this.state.copyWith(
        isPlaying: isPlaying,
        isLoading: isLoading,
      );
    }, onError: (e) {
      print('AudioPlayer error: $e');
    });

    // Listen to position changes
    _positionSubscription = _player.positionStream.listen((position) {
      this.state = this.state.copyWith(position: position);
    });

    // Listen to duration changes
    _durationSubscription = _player.durationStream.listen((duration) {
      if (duration != null) {
        this.state = this.state.copyWith(duration: duration);
      }
    });

    // Listen to buffered position changes
    _bufferedSubscription = _player.bufferedPositionStream.listen((buffered) {
      this.state = this.state.copyWith(bufferedPosition: buffered);
    });
  }

  final Map<String, String> _prefetchedUrls = {};

  void _prefetchNextSong() async {
    if (state.queue.isEmpty) return;
    int nextIndex = state.currentIndex + 1;
    if (state.isShuffleEnabled) return;
    
    if (nextIndex >= state.queue.length) {
      if (state.repeatState == RepeatState.all) {
        nextIndex = 0;
      } else {
        return;
      }
    }
    
    final nextSong = state.queue[nextIndex];
    final dbNotifier = _ref.read(databaseProvider.notifier);
    final localPath = await dbNotifier.getDownloadedTrackPath(nextSong.id);
    if (localPath != null) return; // Already offline
    
    if (_prefetchedUrls.containsKey(nextSong.id)) return;
    
    try {
      final youtubeService = _ref.read(youtubeServiceProvider);
      final streamUrl = await youtubeService.getAudioStreamUrl(nextSong.id);
      _prefetchedUrls[nextSong.id] = streamUrl;
      print('Prefetched URL for next track: ${nextSong.title}');
    } catch (e) {
      print('Failed to prefetch next track: $e');
    }
  }

  void playSong(TrackModel song, List<TrackModel> currentQueue) {
    final index = currentQueue.indexWhere((s) => s.id == song.id);
    setQueue(currentQueue, index >= 0 ? index : 0);
  }

  void playNext(TrackModel song) {
    if (state.queue.isEmpty) {
      setQueue([song], 0);
      return;
    }

    final queue = List<TrackModel>.from(state.queue);
    
    // Avoid duplicates in active queue
    queue.removeWhere((s) => s.id == song.id);

    final insertIndex = state.currentIndex + 1;
    if (insertIndex >= queue.length) {
      queue.add(song);
    } else {
      queue.insert(insertIndex, song);
    }

    state = state.copyWith(queue: queue);
    _prefetchNextSong();
  }

  void addToQueue(TrackModel song) {
    if (state.queue.isEmpty) {
      setQueue([song], 0);
      return;
    }

    final queue = List<TrackModel>.from(state.queue);
    
    // Avoid duplicate in queue
    if (!queue.any((s) => s.id == song.id)) {
      queue.add(song);
      state = state.copyWith(queue: queue);
      _prefetchNextSong();
    }
  }

  Future<void> setQueue(List<TrackModel> queue, int startIndex) async {
    if (queue.isEmpty) return;
    
    final validIndex = (startIndex >= 0 && startIndex < queue.length) ? startIndex : 0;
    final targetSong = queue[validIndex];

    state = this.state.copyWith(
      queue: queue,
      currentIndex: validIndex,
      currentSong: () => targetSong,
      isLoading: true,
      position: Duration.zero,
      duration: targetSong.duration,
    );

    // Save to database listening history & cache its metadata
    _ref.read(databaseProvider.notifier).addToHistory(targetSong);

    // Update system lockscreen controls and notifications
    (audioHandler as BeatFlowAudioHandler).updateMediaItemFromTrack(targetSong);

    // Prefetch next song's URL in the background
    _prefetchNextSong();

    try {
      final dbNotifier = _ref.read(databaseProvider.notifier);
      final localPath = await dbNotifier.getDownloadedTrackPath(targetSong.id);
      
      if (localPath != null) {
        print('Playing downloaded offline track: ${targetSong.title}');
        await _player.setAudioSource(AudioSource.file(localPath));
      } else {
        // Fetch fresh streaming audio URL or use prefetched URL
        String streamUrl;
        if (_prefetchedUrls.containsKey(targetSong.id)) {
          streamUrl = _prefetchedUrls.remove(targetSong.id)!;
          print('Using prefetched stream URL for: ${targetSong.title}');
        } else {
          final youtubeService = _ref.read(youtubeServiceProvider);
          streamUrl = await youtubeService.getAudioStreamUrl(targetSong.id);
        }
        
        if (kIsWeb) {
          streamUrl = 'https://corsproxy.io/?${Uri.encodeComponent(streamUrl)}';
          await _player.setUrl(streamUrl);
        } else {
          await _player.setUrl(
            streamUrl,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Referer': 'https://www.youtube.com/',
            },
          );
        }
      }
      _player.play();
    } catch (e) {
      print('Error loading audio stream: $e. Skipping song.');
      // Try to skip to next track if streaming failed
      next();
    }
  }

  void play() {
    if (state.currentSong == null && state.queue.isNotEmpty) {
      setQueue(state.queue, 0);
    } else {
      _player.play();
    }
  }

  void pause() {
    _player.pause();
  }

  void seek(Duration position) {
    _player.seek(position);
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void next() {
    if (state.queue.isEmpty) return;

    int nextIndex = state.currentIndex + 1;

    if (state.isShuffleEnabled) {
      if (state.queue.length > 1) {
        final random = DateTime.now().millisecond % state.queue.length;
        nextIndex = random == state.currentIndex ? (random + 1) % state.queue.length : random;
      } else {
        nextIndex = 0;
      }
    }

    if (nextIndex >= state.queue.length) {
      if (state.repeatState == RepeatState.all) {
        nextIndex = 0;
      } else {
        _player.stop();
        state = state.copyWith(
          isPlaying: false,
          position: Duration.zero,
        );
        return;
      }
    }

    setQueue(state.queue, nextIndex);
  }

  void previous() {
    if (state.queue.isEmpty) return;

    // If song is played more than 3 seconds, restart the song first
    if (state.position.inSeconds > 3) {
      seek(Duration.zero);
      return;
    }

    int prevIndex = state.currentIndex - 1;
    if (prevIndex < 0) {
      if (state.repeatState == RepeatState.all) {
        prevIndex = state.queue.length - 1;
      } else {
        seek(Duration.zero);
        return;
      }
    }

    setQueue(state.queue, prevIndex);
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffleEnabled: !state.isShuffleEnabled);
  }

  void toggleRepeat() {
    final nextRepeat = RepeatState.values[(state.repeatState.index + 1) % RepeatState.values.length];
    state = state.copyWith(repeatState: nextRepeat);
  }

  void _handleSongCompletion() {
    if (state.repeatState == RepeatState.one) {
      seek(Duration.zero);
      _player.play();
    } else {
      next();
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _bufferedSubscription?.cancel();
    super.dispose();
  }
}

final audioPlayerProvider = StateNotifierProvider<AudioPlayerStateNotifier, AudioPlayerState>((ref) {
  // Alias the notifier class if necessary, or rename it.
  // We used AudioPlayerNotifier. Let's make sure it matches the type parameters.
  return AudioPlayerNotifier(ref);
});

typedef AudioPlayerStateNotifier = AudioPlayerNotifier;
