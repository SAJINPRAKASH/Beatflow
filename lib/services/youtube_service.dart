import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide SearchFilter;
import 'package:dio/dio.dart';
import 'package:ytmusicapi_dart/ytmusicapi_dart.dart';
import 'package:ytmusicapi_dart/enums.dart';
import 'package:hive/hive.dart';
import '../models/models.dart';

class YoutubeService {
  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio();
  YTMusic? _ytMusic;

  Future<YTMusic> _getYtMusic() async {
    _ytMusic ??= await YTMusic.create();
    return _ytMusic!;
  }

  /// Search tracks on YouTube Music and YouTube
  Future<List<TrackModel>> searchTracks(String query) async {
    try {
      if (kIsWeb) {
        String searchQuery = query;
        final cleanQuery = query.toLowerCase();
        if (!cleanQuery.contains('music') && 
            !cleanQuery.contains('song') && 
            !cleanQuery.contains('audio') && 
            !cleanQuery.contains('lyrics') && 
            !cleanQuery.contains('album')) {
          searchQuery = '$query music';
        }
        // Fetch via CORS proxy to bypass browser scrap blocks
        final url = 'https://corsproxy.io/?${Uri.encodeComponent('https://www.youtube.com/results?search_query=${Uri.encodeComponent(searchQuery)}')}';
        final response = await _dio.get(url);
        final html = response.data as String;
        return _parseSearchWeb(html);
      } else {
        // Native search on mobile/desktop using direct YouTube Music API client
        final ytmusic = await _getYtMusic();
        final List<dynamic> searchResults = await ytmusic.search(query, filter: SearchFilter.songs);
        final List<TrackModel> tracks = [];
        
        for (final item in searchResults) {
          final map = item as Map<String, dynamic>;
          final videoId = map['videoId'] as String?;
          if (videoId == null) continue;
          
          final title = map['title'] as String? ?? 'Unknown Title';
          
          // Extract artist
          String artist = 'Unknown Artist';
          final artistsList = map['artists'] as List?;
          if (artistsList != null && artistsList.isNotEmpty) {
            artist = artistsList.first['name'] as String? ?? 'Unknown Artist';
          }
          
          // Extract album
          String albumName = 'YouTube Music';
          final albumMap = map['album'];
          if (albumMap is Map) {
            albumName = albumMap['name'] as String? ?? 'YouTube Music';
          }
          
          // Extract duration
          int durationSecs = map['duration_seconds'] as int? ?? 180;
          final duration = Duration(seconds: durationSecs);
          
          // Extract thumbnail
          String thumbnailUrl = '';
          final thumbnailsList = map['thumbnails'] as List?;
          if (thumbnailsList != null && thumbnailsList.isNotEmpty) {
            thumbnailUrl = thumbnailsList.last['url'] as String? ?? '';
          }
          
          tracks.add(TrackModel(
            id: videoId,
            title: title,
            artist: _cleanArtistName(artist),
            album: albumName,
            thumbnail: thumbnailUrl,
            duration: duration,
          ));
        }
        
        if (tracks.isEmpty) {
          return _fallbackSearchYtExplode(query);
        }
        
        return tracks;
      }
    } catch (e) {
      print('Error searching YouTube Music: $e. Falling back...');
      return _fallbackSearchYtExplode(query);
    }
  }

  Future<List<TrackModel>> _fallbackSearchYtExplode(String query) async {
    try {
      final searchResults = await _yt.search.search(query);
      final List<TrackModel> tracks = [];
      
      for (final video in searchResults) {
        final duration = video.duration ?? const Duration(minutes: 3);
        if (duration.inMinutes > 15) continue;

        tracks.add(TrackModel(
          id: video.id.value,
          title: video.title,
          artist: _cleanArtistName(video.author),
          album: 'YouTube Music',
          thumbnail: video.thumbnails.mediumResUrl,
          duration: duration,
        ));
      }
      
      return tracks;
    } catch (e) {
      print('Fallback search failed: $e');
      return [];
    }
  }

  /// Get direct audio stream URL for a given video ID (with self-healing rate-limit fallback)
  Future<String> getAudioStreamUrl(String videoId) async {
    try {
      // First attempt: Standard youtube_explode stream retrieval using androidVr client
      // to bypass Proof of Origin (PO) tokens and 403 Forbidden streaming blocks.
      var manifest = await _yt.videos.streams.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidVr],
      );
      
      // Fallback: If no audio streams returned, try fetching with safari and ios clients.
      if (manifest.audioOnly.isEmpty) {
        manifest = await _yt.videos.streams.getManifest(
          videoId,
          ytClients: [YoutubeApiClient.safari, YoutubeApiClient.ios],
        );
      }
      
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isNotEmpty) {
        // Prioritize universally supported AAC/m4a streams (Container.mp4)
        final aacStreams = audioStreams.where((s) => s.container.name == 'mp4');
        if (aacStreams.isNotEmpty) {
          final bestAac = aacStreams.withHighestBitrate();
          return _forceHttps(bestAac.url.toString());
        }

        final bestAudio = audioStreams.withHighestBitrate();
        return _forceHttps(bestAudio.url.toString());
      }
      
      final muxedStreams = manifest.muxed;
      if (muxedStreams.isNotEmpty) {
        final bestMuxed = muxedStreams.withHighestBitrate();
        return _forceHttps(bestMuxed.url.toString());
      }
      
      throw Exception('No playable streams found in manifest');
    } catch (e) {
      print('Standard stream extraction failed: $e. Attempting proxied fallback...');
      
      // Fallback: Fetch watch page via CORS proxy (which routes through proxy IP) 
      // and parse ytInitialPlayerResponse directly.
      try {
        final url = 'https://corsproxy.io/?${Uri.encodeComponent('https://www.youtube.com/watch?v=$videoId&hl=en')}';
        final response = await _dio.get(
          url,
          options: Options(
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
          ),
        );
        final html = response.data as String;
        
        final extractedUrl = _extractAudioUrlFromPlayerResponse(html);
        if (extractedUrl != null) {
          print('Successfully recovered stream URL via proxied scraper!');
          return _forceHttps(extractedUrl);
        }
      } catch (fallbackErr) {
        print('Proxied fallback stream extraction failed: $fallbackErr');
      }
      
      rethrow;
    }
  }

  /// Helper to force audio stream URLs to use HTTPS protocol
  String _forceHttps(String url) {
    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  /// Fetch trending tracks (simulates trending tab)
  Future<List<TrackModel>> getTrendingTracks() async {
    return searchTracks('trending music chart 2026');
  }

  /// Fetch new releases (simulates new releases tab)
  Future<List<TrackModel>> getNewReleases() async {
    return searchTracks('new music releases album 2026');
  }

  /// Fetch recommendations based on recently played seed tracks and user preferences
  Future<List<TrackModel>> getRecommendations(List<String> seedTrackIds) async {
    List<TrackModel> prefTracks = [];
    List<String> favLangs = [];
    List<String> favArtists = [];
    
    try {
      final settingsBox = Hive.isBoxOpen('beatflow_settings') ? Hive.box('beatflow_settings') : null;
      final List<dynamic>? savedLangs = settingsBox?.get('fav_languages');
      final List<dynamic>? savedArtists = settingsBox?.get('fav_artists');
      if (savedLangs != null) favLangs = List<String>.from(savedLangs);
      if (savedArtists != null) favArtists = List<String>.from(savedArtists);
    } catch (e) {
      print('Error reading preferences: $e');
    }

    final queryLangs = favLangs.join(' ');
    final queryArtists = favArtists.join(' ');
    final preferenceQuery = '$queryLangs $queryArtists'.trim();

    if (preferenceQuery.isNotEmpty) {
      try {
        prefTracks = await searchTracks('$preferenceQuery hit songs');
      } catch (e) {
        print('Error fetching preference tracks: $e');
      }
    }

    // If history is empty, return preference-driven tracks or trending
    if (seedTrackIds.isEmpty) {
      if (prefTracks.isNotEmpty) return prefTracks;
      return getTrendingTracks();
    }

    // Fetch seed-related tracks
    List<TrackModel> relatedTracks = [];
    try {
      final String seedId = seedTrackIds.first;
      if (kIsWeb) {
        relatedTracks = await searchTracks('related to $seedId');
      } else {
        final video = await _yt.videos.get(VideoId(seedId));
        final relatedVideos = await _yt.videos.getRelatedVideos(video);
        if (relatedVideos != null) {
          for (final video in relatedVideos.take(8)) {
            final duration = video.duration ?? const Duration(minutes: 3);
            if (duration.inMinutes > 15) continue;
            relatedTracks.add(TrackModel(
              id: video.id.value,
              title: video.title,
              artist: _cleanArtistName(video.author),
              album: 'Recommended',
              thumbnail: video.thumbnails.mediumResUrl,
              duration: duration,
            ));
          }
        }
      }
    } catch (e) {
      print('Error fetching related tracks: $e');
    }

    // Merge and interleave preference tracks and related tracks
    final List<TrackModel> mergedTracks = [];
    int prefIndex = 0;
    int relatedIndex = 0;

    while (mergedTracks.length < 12 && (prefIndex < prefTracks.length || relatedIndex < relatedTracks.length)) {
      if (relatedIndex < relatedTracks.length) {
        final song = relatedTracks[relatedIndex++];
        if (!mergedTracks.any((t) => t.id == song.id)) {
          mergedTracks.add(song);
        }
      }
      if (prefIndex < prefTracks.length && mergedTracks.length < 12) {
        final song = prefTracks[prefIndex++];
        if (!mergedTracks.any((t) => t.id == song.id)) {
          mergedTracks.add(song);
        }
      }
    }

    if (mergedTracks.isEmpty) {
      return getTrendingTracks();
    }
    return mergedTracks;
  }

  /// Helper to clean channel names like 'XYZ - Topic' or 'ArtistVEVO'
  String _cleanArtistName(String author) {
    String clean = author;
    if (clean.endsWith(' - Topic')) {
      clean = clean.substring(0, clean.length - 8);
    }
    if (clean.endsWith('VEVO')) {
      clean = clean.substring(0, clean.length - 4);
    }
    return clean.trim();
  }

  /// Parser for YouTube results web HTML
  List<TrackModel> _parseSearchWeb(String html) {
    final List<TrackModel> tracks = [];
    try {
      final match = RegExp(r'ytInitialData\s*=\s*({.*?});').firstMatch(html) ??
                    RegExp(r'ytInitialData\s*=\s*({.*})').firstMatch(html);
      if (match == null) return [];
      
      final jsonStr = match.group(1);
      if (jsonStr == null) return [];
      
      final Map<String, dynamic> data = json.decode(jsonStr) as Map<String, dynamic>;
      
      final contents = data['contents']?['twoColumnSearchResultRenderer']
                           ?['primaryContents']?['sectionListRenderer']
                           ?['contents'];
      if (contents == null || contents is! List) return [];
      
      for (final section in contents) {
        final itemSection = section['itemSectionRenderer'];
        if (itemSection == null) continue;
        final items = itemSection['contents'];
        if (items == null || items is! List) continue;
        
        for (final item in items) {
          final video = item['videoRenderer'];
          if (video == null) continue;
          
          final videoId = video['videoId'] as String?;
          if (videoId == null) continue;
          
          // Extract title
          String title = '';
          final titleRuns = video['title']?['runs'];
          if (titleRuns != null && titleRuns is List && titleRuns.isNotEmpty) {
            title = titleRuns[0]['text'] as String? ?? '';
          }
          
          // Extract author/artist
          String artist = '';
          final ownerRuns = video['ownerText']?['runs'];
          if (ownerRuns != null && ownerRuns is List && ownerRuns.isNotEmpty) {
            artist = ownerRuns[0]['text'] as String? ?? '';
          } else {
            final authorRuns = video['longBylineText']?['runs'];
            if (authorRuns != null && authorRuns is List && authorRuns.isNotEmpty) {
              artist = authorRuns[0]['text'] as String? ?? '';
            }
          }
          
          // Extract thumbnail
          String thumbnail = '';
          final thumbnails = video['thumbnail']?['thumbnails'];
          if (thumbnails != null && thumbnails is List && thumbnails.isNotEmpty) {
            thumbnail = thumbnails.last['url'] as String? ?? '';
          }
          
          // Extract duration
          Duration duration = const Duration(minutes: 3);
          final simpleText = video['lengthText']?['simpleText'] as String?;
          if (simpleText != null) {
            duration = _parseDurationString(simpleText);
          }
          
          tracks.add(TrackModel(
            id: videoId,
            title: title,
            artist: _cleanArtistName(artist),
            album: 'YouTube Music',
            thumbnail: thumbnail,
            duration: duration,
          ));
        }
      }
    } catch (e) {
      print('Error parsing web search results: $e');
    }
    return tracks;
  }

  /// Extracts direct audio stream URL from ytInitialPlayerResponse object in HTML
  String? _extractAudioUrlFromPlayerResponse(String html) {
    try {
      final match = RegExp(r'ytInitialPlayerResponse\s*=\s*({.*?});').firstMatch(html) ??
                    RegExp(r'ytInitialPlayerResponse\s*=\s*({.*})').firstMatch(html);
      if (match == null) return null;
      
      final jsonStr = match.group(1);
      if (jsonStr == null) return null;
      
      final Map<String, dynamic> data = json.decode(jsonStr) as Map<String, dynamic>;
      final streamingData = data['streamingData'];
      if (streamingData == null) return null;
      
      final adaptiveFormats = streamingData['adaptiveFormats'];
      if (adaptiveFormats == null || adaptiveFormats is! List) return null;
      
      final List<Map<String, dynamic>> audioStreams = [];
      for (final format in adaptiveFormats) {
        final mimeType = format['mimeType'] as String? ?? '';
        if (mimeType.contains('audio/')) {
          audioStreams.add(Map<String, dynamic>.from(format as Map));
        }
      }
      
      if (audioStreams.isEmpty) return null;
      
      // Prioritize AAC format (container name mp4 or description containing mp4a)
      final aacStreams = audioStreams.where((s) {
        final mimeType = s['mimeType'] as String? ?? '';
        return mimeType.contains('mp4') || mimeType.contains('aac') || mimeType.contains('mp4a');
      }).toList();
      
      final streamsToChoose = aacStreams.isNotEmpty ? aacStreams : audioStreams;
      
      // Sort by bitrate descending
      streamsToChoose.sort((a, b) {
        final brA = a['bitrate'] as int? ?? 0;
        final brB = b['bitrate'] as int? ?? 0;
        return brB.compareTo(brA);
      });
      
      // Return first format that has a direct url or construct from cipher
      for (final s in streamsToChoose) {
        final url = s['url'] as String?;
        if (url != null && url.isNotEmpty) {
          return url;
        }
        
        final cipher = (s['signatureCipher'] as String?) ?? (s['cipher'] as String?);
        if (cipher != null && cipher.isNotEmpty) {
          final params = Uri.splitQueryString(cipher);
          final urlParam = params['url'];
          final sig = params['s'];
          final sigParam = params['sp'] ?? 'sig';
          if (urlParam != null) {
            if (sig != null) {
              return '$urlParam&$sigParam=$sig';
            }
            return urlParam;
          }
        }
      }
    } catch (e) {
      print('Error parsing ytInitialPlayerResponse: $e');
    }
    return null;
  }

  Duration _parseDurationString(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = int.tryParse(parts[1]) ?? 0;
      return Duration(minutes: minutes, seconds: seconds);
    } else if (parts.length == 3) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      final seconds = int.tryParse(parts[2]) ?? 0;
      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    }
    return const Duration(minutes: 3);
  }

  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final url = 'https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=${Uri.encodeComponent(query)}';
      final response = await _dio.get(url);
      final data = response.data;
      
      List<dynamic>? suggestionsList;
      if (data is List && data.length > 1) {
        suggestionsList = data[1] as List?;
      } else if (data is String) {
        final decoded = json.decode(data);
        if (decoded is List && decoded.length > 1) {
          suggestionsList = decoded[1] as List?;
        }
      }
      
      if (suggestionsList != null) {
        return suggestionsList.map((e) => e.toString()).toList();
      }
    } catch (e) {
      print('Error getting search suggestions: $e');
    }
    return [];
  }

  void dispose() {
    _yt.close();
    _ytMusic?.close();
  }
}

final youtubeServiceProvider = Provider<YoutubeService>((ref) {
  final service = YoutubeService();
  ref.onDispose(() => service.dispose());
  return service;
});
