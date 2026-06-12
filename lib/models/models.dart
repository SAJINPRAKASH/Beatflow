class TrackModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String thumbnail;
  final Duration duration;

  TrackModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.thumbnail,
    required this.duration,
  });

  String get durationString {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'thumbnail': thumbnail,
      'duration_ms': duration.inMilliseconds,
    };
  }

  factory TrackModel.fromJson(Map<dynamic, dynamic> json) {
    return TrackModel(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
      thumbnail: json['thumbnail'] as String,
      duration: Duration(milliseconds: json['duration_ms'] as int),
    );
  }

  TrackModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? thumbnail,
    Duration? duration,
  }) {
    return TrackModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      thumbnail: thumbnail ?? this.thumbnail,
      duration: duration ?? this.duration,
    );
  }
}

class PlaylistModel {
  final String id;
  final String name;
  final List<String> trackIds;

  PlaylistModel({
    required this.id,
    required this.name,
    required this.trackIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'track_ids': trackIds,
    };
  }

  factory PlaylistModel.fromJson(Map<dynamic, dynamic> json) {
    return PlaylistModel(
      id: json['id'] as String,
      name: json['name'] as String,
      trackIds: List<String>.from(json['track_ids'] as List),
    );
  }

  PlaylistModel copyWith({
    String? id,
    String? name,
    List<String>? trackIds,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      trackIds: trackIds ?? this.trackIds,
    );
  }
}
