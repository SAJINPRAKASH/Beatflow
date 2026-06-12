import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'youtube_service.dart';

class DownloadTask {
  final TrackModel track;
  final double progress; // 0.0 to 1.0
  final String status; // 'pending', 'downloading', 'completed', 'failed'
  final String? errorMessage;
  final CancelToken? cancelToken;

  DownloadTask({
    required this.track,
    this.progress = 0.0,
    this.status = 'pending',
    this.errorMessage,
    this.cancelToken,
  });

  DownloadTask copyWith({
    TrackModel? track,
    double? progress,
    String? status,
    String? errorMessage,
    CancelToken? cancelToken,
  }) {
    return DownloadTask(
      track: track ?? this.track,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      cancelToken: cancelToken ?? this.cancelToken,
    );
  }
}

class DownloadNotifier extends StateNotifier<Map<String, DownloadTask>> {
  final Ref _ref;

  DownloadNotifier(this._ref) : super({});

  Future<void> startDownload(TrackModel track) async {
    final dbNotifier = _ref.read(databaseProvider.notifier);
    final dbState = _ref.read(databaseProvider);
    final youtubeService = _ref.read(youtubeServiceProvider);

    if (dbState.downloadedTrackIds.contains(track.id)) {
      return; // Already downloaded
    }

    if (state.containsKey(track.id) && state[track.id]?.status == 'downloading') {
      return; // Already downloading
    }

    final cancelToken = CancelToken();

    // Initialize/Update state with downloading task
    state = {
      ...state,
      track.id: DownloadTask(
        track: track,
        status: 'downloading',
        progress: 0.0,
        cancelToken: cancelToken,
      ),
    };

    try {
      // 1. Get stream URL
      final streamUrl = await youtubeService.getAudioStreamUrl(track.id);

      // 2. Locate downloads directory
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final filePath = '${downloadsDir.path}/${track.id}.mp3';

      // 3. Download file via Dio with User-Agent & Referer to prevent 403 Forbidden
      final dio = Dio();
      await dio.download(
        streamUrl,
        filePath,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://www.youtube.com/',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total != -1 && !cancelToken.isCancelled) {
            final progress = received / total;
            state = {
              ...state,
              track.id: state[track.id]!.copyWith(progress: progress),
            };
          }
        },
      );

      // 4. Save metadata & update DB state
      dbNotifier.saveTrackMetadata(track);
      
      final updatedDownloads = Set<String>.from(dbState.downloadedTrackIds)..add(track.id);
      await Hive.box('beatflow_settings').put('downloaded_ids', updatedDownloads.toList());
      dbNotifier.state = dbState.copyWith(downloadedTrackIds: updatedDownloads);

      // 5. Complete task
      state = {
        ...state,
        track.id: state[track.id]!.copyWith(status: 'completed', progress: 1.0),
      };
    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
        print('Download cancelled for track ${track.id}');
        // Clean up partial file
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final file = File('${appDir.path}/downloads/${track.id}.mp3');
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
        
        final updated = Map<String, DownloadTask>.from(state)..remove(track.id);
        state = updated;
      } else {
        print('Download failed for track ${track.id}: $e');
        state = {
          ...state,
          track.id: state[track.id]!.copyWith(
            status: 'failed',
            errorMessage: e.toString(),
          ),
        };
        rethrow;
      }
    }
  }

  void cancelDownload(String trackId) {
    if (state.containsKey(trackId)) {
      final task = state[trackId]!;
      task.cancelToken?.cancel();
      final updated = Map<String, DownloadTask>.from(state)..remove(trackId);
      state = updated;
    }
  }

  void removeTask(String trackId) {
    final updated = Map<String, DownloadTask>.from(state)..remove(trackId);
    state = updated;
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, Map<String, DownloadTask>>((ref) {
  return DownloadNotifier(ref);
});
