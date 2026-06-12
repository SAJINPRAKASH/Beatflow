import 'package:flutter_test/flutter_test.dart';
import 'package:beatflow/models/models.dart';

void main() {
  group('Data Models Serialization Tests', () {
    test('TrackModel toJson and fromJson conversion matches', () {
      final track = TrackModel(
        id: 'dQw4w9WgXcQ',
        title: 'Focus Dimension',
        artist: 'SoundHelix Collective',
        album: 'Quantum Waves',
        thumbnail: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=400',
        duration: const Duration(minutes: 6, seconds: 12),
      );

      final json = track.toJson();
      expect(json['id'], 'dQw4w9WgXcQ');
      expect(json['duration_ms'], 372000);

      final decoded = TrackModel.fromJson(json);
      expect(decoded.id, track.id);
      expect(decoded.title, track.title);
      expect(decoded.artist, track.artist);
      expect(decoded.album, track.album);
      expect(decoded.thumbnail, track.thumbnail);
      expect(decoded.duration, track.duration);
    });

    test('PlaylistModel toJson and fromJson conversion matches', () {
      final playlist = PlaylistModel(
        id: 'pl_test',
        name: 'My Custom Vibe',
        trackIds: ['track_1', 'track_2'],
      );

      final json = playlist.toJson();
      expect(json['id'], 'pl_test');
      expect(json['track_ids'], ['track_1', 'track_2']);

      final decoded = PlaylistModel.fromJson(json);
      expect(decoded.id, playlist.id);
      expect(decoded.name, playlist.name);
      expect(decoded.trackIds, playlist.trackIds);
    });
  });
}
