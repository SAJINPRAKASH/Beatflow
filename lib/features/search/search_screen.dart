import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/neumorphic_theme.dart';
import '../../services/database_service.dart';
import '../../services/audio_service.dart';
import '../../services/youtube_service.dart';
import '../../models/models.dart';
import '../../services/download_service.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  List<TrackModel> _searchResults = [];
  List<String> _suggestions = [];
  bool _isLoading = false;
  String _activeSearchQuery = '';
  Timer? _debounceTimer;

  final List<String> _smartQueries = [
    'Malayalam love songs',
    'Gym workout music',
    'Rainy day playlist',
    'Focus music',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onTextChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final query = _searchController.text;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      try {
        final suggestions = await ref.read(youtubeServiceProvider).getSearchSuggestions(query);
        if (mounted && _searchController.text == query) {
          setState(() {
            _suggestions = suggestions;
          });
        }
      } catch (e) {
        print('Error fetching suggestions: $e');
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    // Cancel suggestions display
    _debounceTimer?.cancel();

    setState(() {
      _isLoading = true;
      _activeSearchQuery = query;
      _suggestions = [];
    });

    // Save query to local history in Hive
    ref.read(databaseProvider.notifier).addSearchQuery(query);

    try {
      final youtubeService = ref.read(youtubeServiceProvider);
      final results = await youtubeService.searchTracks(query);
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Search failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search failed. Please try again.')),
        );
      }
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _activeSearchQuery = '';
      _searchResults = [];
      _suggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final dbState = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Header
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: NeumorphicBox(
                      style: NeumorphicStyle.pressed,
                      borderRadius: 16,
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: _performSearch,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search songs, artists, albums...',
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: AppTheme.textSecondary, size: 22),
                          suffixIcon: _activeSearchQuery.isNotEmpty || _searchController.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: _clearSearch,
                                  child: Icon(Icons.clear, color: AppTheme.textSecondary, size: 20),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Smart Search Chips row
            SizedBox(
              height: 54,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _smartQueries.length,
                itemBuilder: (context, index) {
                  final prompt = _smartQueries[index];
                  final isSelected = _activeSearchQuery == prompt;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: GestureDetector(
                      onTap: () {
                        _searchController.text = prompt;
                        _performSearch(prompt);
                      },
                      child: NeumorphicBox(
                        style: isSelected ? NeumorphicStyle.pressed : NeumorphicStyle.flat,
                        borderRadius: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Text(
                          prompt,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Main display area
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textPrimary),
                        strokeWidth: 2.5,
                      ),
                    )
                  : _activeSearchQuery.isEmpty
                      ? (_searchController.text.isNotEmpty && _suggestions.isNotEmpty
                          ? _buildSearchSuggestions()
                          : _buildSearchHistory(dbState))
                      : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            'Search Suggestions',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = _suggestions[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
                title: Text(suggestion, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                trailing: Icon(Icons.north_west, size: 14, color: AppTheme.textSecondary),
                onTap: () {
                  _searchController.text = suggestion;
                  _performSearch(suggestion);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchHistory(DatabaseState dbState) {
    final history = dbState.searchHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              if (history.isNotEmpty)
                TextButton(
                  onPressed: () {
                    ref.read(databaseProvider.notifier).clearSearchHistory();
                  },
                  child: Text('Clear All', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ),
            ],
          ),
        ),
        if (history.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'Search for songs, artists, or moods to get started',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final query = history[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.history, color: AppTheme.textSecondary, size: 20),
                  title: Text(query, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  trailing: Icon(Icons.north_west, size: 14, color: AppTheme.textSecondary),
                  onTap: () {
                    _searchController.text = query;
                    _performSearch(query);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'No matches found. Try searching Malayalam love songs, focus beats, or artist names.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final song = _searchResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GestureDetector(
            onTap: () {
              ref.read(audioPlayerProvider.notifier).playSong(song, _searchResults);
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
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.more_horiz,
                      color: AppTheme.textSecondary,
                    ),
                    iconSize: 22,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      _showSearchSongOptions(context, ref, song);
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSearchSongOptions(BuildContext context, WidgetRef ref, TrackModel song) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final liveDbState = ref.watch(databaseProvider);
          final liveIsDownloaded = liveDbState.downloadedTrackIds.contains(song.id);
          final liveDownloadState = ref.watch(downloadProvider);
          final liveDownloadTask = liveDownloadState[song.id];
          final liveIsDownloading = liveDownloadTask?.status == 'downloading';
          final progressPercent = ((liveDownloadTask?.progress ?? 0.0) * 100).toStringAsFixed(0);

          return AlertDialog(
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
                ),
              ],
            ),
          );
        },
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
