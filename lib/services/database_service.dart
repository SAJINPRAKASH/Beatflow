import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../models/models.dart';
import 'youtube_service.dart';

class DatabaseState {
  final List<PlaylistModel> playlists;
  final Set<String> likedTrackIds;
  final List<String> searchHistory;
  final List<String> listeningHistory;
  final Map<String, TrackModel> trackMetadata;
  final String theme;
  final String audioQuality;
  final Set<String> downloadedTrackIds;
  final bool lowSpecMode;

  DatabaseState({
    required this.playlists,
    required this.likedTrackIds,
    required this.searchHistory,
    required this.listeningHistory,
    required this.trackMetadata,
    required this.theme,
    required this.audioQuality,
    required this.downloadedTrackIds,
    required this.lowSpecMode,
  });

  // Helper to get tracks that are liked
  List<TrackModel> get likedTracks {
    return likedTrackIds
        .map((id) => trackMetadata[id])
        .whereType<TrackModel>()
        .toList();
  }

  // Helper to get tracks that are in history
  List<TrackModel> get historyTracks {
    return listeningHistory
        .map((id) => trackMetadata[id])
        .whereType<TrackModel>()
        .toList();
  }

  // Helper to get tracks that are downloaded
  List<TrackModel> get downloadedTracks {
    return downloadedTrackIds
        .map((id) => trackMetadata[id])
        .whereType<TrackModel>()
        .toList();
  }

  // Helper to get all stored tracks
  List<TrackModel> get allSongs {
    return trackMetadata.values.toList();
  }

  DatabaseState copyWith({
    List<PlaylistModel>? playlists,
    Set<String>? likedTrackIds,
    List<String>? searchHistory,
    List<String>? listeningHistory,
    Map<String, TrackModel>? trackMetadata,
    String? theme,
    String? audioQuality,
    Set<String>? downloadedTrackIds,
    bool? lowSpecMode,
  }) {
    return DatabaseState(
      playlists: playlists ?? this.playlists,
      likedTrackIds: likedTrackIds ?? this.likedTrackIds,
      searchHistory: searchHistory ?? this.searchHistory,
      listeningHistory: listeningHistory ?? this.listeningHistory,
      trackMetadata: trackMetadata ?? this.trackMetadata,
      theme: theme ?? this.theme,
      audioQuality: audioQuality ?? this.audioQuality,
      downloadedTrackIds: downloadedTrackIds ?? this.downloadedTrackIds,
      lowSpecMode: lowSpecMode ?? this.lowSpecMode,
    );
  }
}

class DatabaseNotifier extends StateNotifier<DatabaseState> {
  DatabaseNotifier() : super(_initialState());

  static const String _boxTracks = 'beatflow_tracks';
  static const String _boxFavorites = 'beatflow_favorites';
  static const String _boxHistory = 'beatflow_history';
  static const String _boxPlaylists = 'beatflow_playlists';
  static const String _boxSettings = 'beatflow_settings';

  static DatabaseState _initialState() {
    // Open boxes synchronously if possible or load empty.
    // In Flutter we initialize and open boxes in main().
    // If they aren't open yet (e.g. in test env), fallback to memory maps.
    final tracksBox = Hive.isBoxOpen(_boxTracks) ? Hive.box(_boxTracks) : null;
    final favBox = Hive.isBoxOpen(_boxFavorites) ? Hive.box(_boxFavorites) : null;
    final histBox = Hive.isBoxOpen(_boxHistory) ? Hive.box(_boxHistory) : null;
    final playlistsBox = Hive.isBoxOpen(_boxPlaylists) ? Hive.box(_boxPlaylists) : null;
    final settingsBox = Hive.isBoxOpen(_boxSettings) ? Hive.box(_boxSettings) : null;

    final Map<String, TrackModel> trackMetadata = {};
    if (tracksBox != null) {
      for (final key in tracksBox.keys) {
        final val = tracksBox.get(key);
        if (val != null) {
          try {
            final map = Map<String, dynamic>.from(val as Map);
            trackMetadata[key as String] = TrackModel.fromJson(map);
          } catch (e) {
            print('Error loading track key $key: $e');
          }
        }
      }
    }

    final Set<String> likedTrackIds = {};
    if (favBox != null) {
      final list = favBox.get('liked_ids');
      if (list != null) {
        likedTrackIds.addAll(List<String>.from(list as List));
      }
    }

    final List<String> listeningHistory = [];
    if (histBox != null) {
      final list = histBox.get('history_ids');
      if (list != null) {
        listeningHistory.addAll(List<String>.from(list as List));
      }
    }

    final List<String> searchHistory = [];
    if (settingsBox != null) {
      final list = settingsBox.get('search_history');
      if (list != null) {
        searchHistory.addAll(List<String>.from(list as List));
      }
    }

    final List<PlaylistModel> playlists = [];
    if (playlistsBox != null) {
      for (final key in playlistsBox.keys) {
        final val = playlistsBox.get(key);
        if (val != null) {
          try {
            final map = Map<String, dynamic>.from(val as Map);
            playlists.add(PlaylistModel.fromJson(map));
          } catch (e) {
            print('Error loading playlist key $key: $e');
          }
        }
      }
    }

    // Default Settings
    final theme = settingsBox?.get('theme', defaultValue: 'light') as String? ?? 'light';
    final audioQuality = settingsBox?.get('audio_quality', defaultValue: 'high') as String? ?? 'high';

    final Set<String> downloadedTrackIds = {};
    if (settingsBox != null) {
      final list = settingsBox.get('downloaded_ids');
      if (list != null) {
        downloadedTrackIds.addAll(List<String>.from(list as List));
      }
    }

    final lowSpecMode = settingsBox?.get('low_spec_mode', defaultValue: false) as bool? ?? false;

    // If completely empty, we will seed default tracks & playlists
    if (trackMetadata.isEmpty) {
      _seedDefaultData(tracksBox, favBox, histBox, playlistsBox);
      // Re-read after seeding
      return _initialState();
    }

    return DatabaseState(
      playlists: playlists,
      likedTrackIds: likedTrackIds,
      searchHistory: searchHistory,
      listeningHistory: listeningHistory,
      trackMetadata: trackMetadata,
      theme: theme,
      audioQuality: audioQuality,
      downloadedTrackIds: downloadedTrackIds,
      lowSpecMode: lowSpecMode,
    );
  }

  static void _seedDefaultData(Box? tracksBox, Box? favBox, Box? histBox, Box? playlistsBox) {
    if (tracksBox == null) return;

    final defaultSongs = [
      TrackModel(
        id: 'Y1V00ZlW9Hk',
        title: 'To Speak Of Solitude',
        artist: 'Brambles',
        album: 'Charcoal',
        thumbnail: 'https://images.unsplash.com/photo-1448375240586-882707db888b?w=400',
        duration: const Duration(minutes: 4, seconds: 21),
      ),
      TrackModel(
        id: 'UdfQ2P-Yh48',
        title: 'Unsayable',
        artist: 'Brambles',
        album: 'Charcoal',
        thumbnail: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400',
        duration: const Duration(minutes: 2, seconds: 52),
      ),
      TrackModel(
        id: '1p_jGvY_s7o',
        title: 'In The Androgynous Dark',
        artist: 'Brambles',
        album: 'Charcoal',
        thumbnail: 'https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=400',
        duration: const Duration(minutes: 4, seconds: 43),
      ),
      TrackModel(
        id: '4z7n1xH9uGg',
        title: 'Salt Photographs',
        artist: 'Brambles',
        album: 'Charcoal',
        thumbnail: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400',
        duration: const Duration(minutes: 6, seconds: 54),
      ),
      TrackModel(
        id: 'L1n9c4fW2yE',
        title: 'Pink And Golden Billows',
        artist: 'Brambles',
        album: 'Charcoal',
        thumbnail: 'https://images.unsplash.com/photo-1475924156734-496f6cac6ec1?w=400',
        duration: const Duration(minutes: 2, seconds: 58),
      ),
      TrackModel(
        id: 'dQw4w9WgXcQ',
        title: 'Focus Dimension',
        artist: 'SoundHelix Collective',
        album: 'Quantum Waves',
        thumbnail: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=400',
        duration: const Duration(minutes: 6, seconds: 12),
      ),
      TrackModel(
        id: 'fWNaR-rxAic',
        title: 'Acoustic Horizon',
        artist: 'SoundHelix Collective',
        album: 'Quantum Waves',
        thumbnail: 'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=400',
        duration: const Duration(minutes: 5, seconds: 45),
      ),
      TrackModel(
        id: '5qap5aO4i9A',
        title: 'Rainy Cafe Study',
        artist: 'Lofi Chill Beats',
        album: 'Late Night Coffee',
        thumbnail: 'https://images.unsplash.com/photo-1515003197210-e0cd71810b5f?w=400',
        duration: const Duration(minutes: 3, seconds: 40),
      ),
      TrackModel(
        id: 'kgx4Vx3qyiE',
        title: 'Sunset Boulevard',
        artist: 'Lofi Chill Beats',
        album: 'Late Night Coffee',
        thumbnail: 'https://images.unsplash.com/photo-1472289065668-ce650ac443d2?w=400',
        duration: const Duration(minutes: 3, seconds: 15),
      ),
    ];

    for (final song in defaultSongs) {
      tracksBox.put(song.id, song.toJson());
    }

    if (favBox != null) {
      favBox.put('liked_ids', ['UdfQ2P-Yh48', '1p_jGvY_s7o']);
    }

    if (histBox != null) {
      histBox.put('history_ids', ['UdfQ2P-Yh48', 'Y1V00ZlW9Hk']);
    }

    if (playlistsBox != null) {
      final pl1 = PlaylistModel(
        id: 'pl_1',
        name: 'Chill Ambient Study',
        trackIds: ['Y1V00ZlW9Hk', 'UdfQ2P-Yh48', '1p_jGvY_s7o', '4z7n1xH9uGg', 'L1n9c4fW2yE'],
      );
      final pl2 = PlaylistModel(
        id: 'pl_2',
        name: 'Workday Focus',
        trackIds: ['dQw4w9WgXcQ', 'fWNaR-rxAic', '5qap5aO4i9A', 'kgx4Vx3qyiE'],
      );
      playlistsBox.put(pl1.id, pl1.toJson());
      playlistsBox.put(pl2.id, pl2.toJson());
    }
  }

  // --- Track Metadata Persistence ---
  void saveTrackMetadata(TrackModel track) {
    final box = Hive.box(_boxTracks);
    box.put(track.id, track.toJson());

    final updatedMetadata = Map<String, TrackModel>.from(state.trackMetadata);
    updatedMetadata[track.id] = track;
    state = state.copyWith(trackMetadata: updatedMetadata);
  }

  // --- Favorites Management ---
  void toggleLikeSong(String trackId) {
    final updatedLikes = Set<String>.from(state.likedTrackIds);
    if (updatedLikes.contains(trackId)) {
      updatedLikes.remove(trackId);
    } else {
      updatedLikes.add(trackId);
    }

    Hive.box(_boxFavorites).put('liked_ids', updatedLikes.toList());
    state = state.copyWith(likedTrackIds: updatedLikes);
  }

  void clearFavorites() {
    Hive.box(_boxFavorites).put('liked_ids', <String>[]);
    state = state.copyWith(likedTrackIds: {});
  }

  // --- Playlists Management ---
  void createPlaylist(String name) {
    final id = 'pl_${DateTime.now().millisecondsSinceEpoch}';
    final playlist = PlaylistModel(id: id, name: name, trackIds: []);

    Hive.box(_boxPlaylists).put(playlist.id, playlist.toJson());
    state = state.copyWith(playlists: [...state.playlists, playlist]);
  }

  void deletePlaylist(String playlistId) {
    Hive.box(_boxPlaylists).delete(playlistId);
    state = state.copyWith(
      playlists: state.playlists.where((p) => p.id != playlistId).toList(),
    );
  }

  void renamePlaylist(String playlistId, String newName) {
    final playlists = state.playlists.map((p) {
      if (p.id == playlistId) {
        final updated = p.copyWith(name: newName);
        Hive.box(_boxPlaylists).put(playlistId, updated.toJson());
        return updated;
      }
      return p;
    }).toList();
    state = state.copyWith(playlists: playlists);
  }

  void addSongToPlaylist(String playlistId, TrackModel track) {
    saveTrackMetadata(track); // Ensure metadata is stored locally
    final playlists = state.playlists.map((playlist) {
      if (playlist.id == playlistId) {
        if (!playlist.trackIds.contains(track.id)) {
          final updated = playlist.copyWith(trackIds: [...playlist.trackIds, track.id]);
          Hive.box(_boxPlaylists).put(playlistId, updated.toJson());
          return updated;
        }
      }
      return playlist;
    }).toList();
    state = state.copyWith(playlists: playlists);
  }

  void removeSongFromPlaylist(String playlistId, String trackId) {
    final playlists = state.playlists.map((playlist) {
      if (playlist.id == playlistId) {
        final updated = playlist.copyWith(
          trackIds: playlist.trackIds.where((id) => id != trackId).toList(),
        );
        Hive.box(_boxPlaylists).put(playlistId, updated.toJson());
        return updated;
      }
      return playlist;
    }).toList();
    state = state.copyWith(playlists: playlists);
  }

  void reorderSongsInPlaylist(String playlistId, int oldIndex, int newIndex) {
    final playlists = state.playlists.map((playlist) {
      if (playlist.id == playlistId) {
        final ids = List<String>.from(playlist.trackIds);
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        final item = ids.removeAt(oldIndex);
        ids.insert(newIndex, item);
        final updated = playlist.copyWith(trackIds: ids);
        Hive.box(_boxPlaylists).put(playlistId, updated.toJson());
        return updated;
      }
      return playlist;
    }).toList();
    state = state.copyWith(playlists: playlists);
  }

  // --- Search History ---
  void addSearchQuery(String query) {
    if (query.trim().isEmpty) return;
    final history = List<String>.from(state.searchHistory);
    history.remove(query);
    history.insert(0, query);
    if (history.length > 8) history.removeLast();

    Hive.box(_boxSettings).put('search_history', history);
    state = state.copyWith(searchHistory: history);
  }

  void clearSearchHistory() {
    Hive.box(_boxSettings).put('search_history', <String>[]);
    state = state.copyWith(searchHistory: []);
  }

  // --- Play History ---
  void addToHistory(TrackModel track) {
    saveTrackMetadata(track); // Store track metadata locally
    final history = List<String>.from(state.listeningHistory);
    history.remove(track.id);
    history.insert(0, track.id);
    if (history.length > 20) history.removeLast();

    Hive.box(_boxHistory).put('history_ids', history);
    state = state.copyWith(listeningHistory: history);
  }

  void clearHistory() {
    Hive.box(_boxHistory).put('history_ids', <String>[]);
    state = state.copyWith(listeningHistory: []);
  }

  // --- App Settings ---
  void changeTheme(String theme) {
    Hive.box(_boxSettings).put('theme', theme);
    state = state.copyWith(theme: theme);
  }

  void changeAudioQuality(String quality) {
    Hive.box(_boxSettings).put('audio_quality', quality);
    state = state.copyWith(audioQuality: quality);
  }

  // --- Local Downloads Management ---
  Future<void> downloadTrack(TrackModel track, YoutubeService youtubeService) async {
    if (state.downloadedTrackIds.contains(track.id)) return;

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
      
      // 3. Download file
      final dio = Dio();
      await dio.download(streamUrl, filePath);
      
      // 4. Save metadata and update state
      saveTrackMetadata(track);
      
      final updatedDownloads = Set<String>.from(state.downloadedTrackIds)..add(track.id);
      Hive.box(_boxSettings).put('downloaded_ids', updatedDownloads.toList());
      
      state = state.copyWith(downloadedTrackIds: updatedDownloads);
    } catch (e) {
      print('Download failed for track ${track.id}: $e');
      rethrow;
    }
  }

  Future<void> deleteDownloadedTrack(String trackId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/downloads/$trackId.mp3');
      if (await file.exists()) {
        await file.delete();
      }
      
      final updatedDownloads = Set<String>.from(state.downloadedTrackIds)..remove(trackId);
      Hive.box(_boxSettings).put('downloaded_ids', updatedDownloads.toList());
      
      state = state.copyWith(downloadedTrackIds: updatedDownloads);
    } catch (e) {
      print('Failed to delete downloaded track $trackId: $e');
    }
  }

  Future<String?> getDownloadedTrackPath(String trackId) async {
    if (!state.downloadedTrackIds.contains(trackId)) return null;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/downloads/$trackId.mp3');
      if (await file.exists()) {
        return file.path;
      }
    } catch (e) {
      print('Error verifying download file: $e');
    }
    return null;
  }

  // --- Low-Spec Mode ---
  void toggleLowSpecMode(bool enabled) {
    Hive.box(_boxSettings).put('low_spec_mode', enabled);
    state = state.copyWith(lowSpecMode: enabled);
  }

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxTracks);
    await Hive.openBox(_boxFavorites);
    await Hive.openBox(_boxHistory);
    await Hive.openBox(_boxPlaylists);
    await Hive.openBox(_boxSettings);
  }
}

final databaseProvider = StateNotifierProvider<DatabaseNotifier, DatabaseState>((ref) {
  return DatabaseNotifier();
});
