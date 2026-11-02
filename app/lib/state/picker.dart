import 'package:flutter/foundation.dart';

int _int(Object? v) => v is num ? v.toInt() : 0;
String _str(Object? v) => v == null ? '' : '$v';

enum AlbumType {
  album('Альбомы'),
  single('Синглы и EP'),
  compilation('Сборники');

  const AlbumType(this.label);
  final String label;

  static AlbumType parse(Object? v) =>
      AlbumType.values.firstWhere((t) => t.name == v, orElse: () => AlbumType.album);
}

class AlbumOption {
  AlbumOption.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        title = _str(j['title']),
        year = _int(j['year']),
        cover = _str(j['cover']),
        count = _int(j['count']),
        type = AlbumType.parse(j['type']),
        explicit = j['explicit'] == true;

  final String id, title, cover;
  final int year, count;
  final AlbumType type;
  final bool explicit;
}

class TrackOption {
  TrackOption.fromJson(Map<String, dynamic> j)
      : id = _str(j['id']),
        title = _str(j['title']),
        artist = _str(j['artist']),
        number = _int(j['number']),
        disc = _int(j['disc']),
        explicit = j['explicit'] == true;

  final String id, title, artist;
  final int number, disc;
  final bool explicit;
}

class ArtistPicker extends ChangeNotifier {
  ArtistPicker(this.albums, {required this.load}) : _selected = {for (final a in albums) a.id};

  final List<AlbumOption> albums;
  final void Function(String albumId) load;

  final Set<String> _selected;
  final _partial = <String, Set<String>>{};
  final _tracks = <String, List<TrackOption>>{};
  final _errors = <String, String>{};
  final _loading = <String>{};
  final _expanded = <String>{};

  List<AlbumType> get types => [
        for (final t in AlbumType.values)
          if (albums.any((a) => a.type == t)) t,
      ];

  Iterable<AlbumOption> ofType(AlbumType t) => albums.where((a) => a.type == t);

  bool? albumState(String id) {
    if (!_selected.contains(id)) return false;
    return _partial.containsKey(id) ? null : true;
  }

  void toggleAlbum(String id) {
    if (albumState(id) == true) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    _partial.remove(id);
    notifyListeners();
  }

  bool? typeState(AlbumType t) {
    final states = ofType(t).map((a) => albumState(a.id)).toSet();
    if (states.length == 1) return states.first;
    return null;
  }

  void toggleType(AlbumType t) {
    final on = typeState(t) != true;
    for (final a in ofType(t)) {
      on ? _selected.add(a.id) : _selected.remove(a.id);
      _partial.remove(a.id);
    }
    notifyListeners();
  }

  void selectAll(bool on) {
    _partial.clear();
    on ? _selected.addAll(albums.map((a) => a.id)) : _selected.clear();
    notifyListeners();
  }

  bool isExpanded(String id) => _expanded.contains(id);
  bool isLoading(String id) => _loading.contains(id);
  String? error(String id) => _errors[id];
  List<TrackOption>? tracks(String id) => _tracks[id];

  void toggleExpanded(String id) {
    if (!_expanded.remove(id)) {
      _expanded.add(id);
      if (!_tracks.containsKey(id) && _loading.add(id)) {
        _errors.remove(id);
        load(id);
      }
    }
    notifyListeners();
  }

  void setTracks(String id, List<TrackOption> list) {
    _loading.remove(id);
    _tracks[id] = list;
    notifyListeners();
  }

  void setError(String id, String message) {
    _loading.remove(id);
    _errors[id] = message;
    _expanded.remove(id);
    notifyListeners();
  }

  bool trackSelected(String albumId, String trackId) =>
      _selected.contains(albumId) && (_partial[albumId]?.contains(trackId) ?? true);

  void toggleTrack(String albumId, String trackId) {
    final all = (_tracks[albumId] ?? const []).map((t) => t.id).toSet();
    final current = _selected.contains(albumId) ? Set.of(_partial[albumId] ?? all) : <String>{};
    if (!current.remove(trackId)) current.add(trackId);
    if (current.isEmpty) {
      _selected.remove(albumId);
      _partial.remove(albumId);
    } else if (current.length == all.length) {
      _selected.add(albumId);
      _partial.remove(albumId);
    } else {
      _selected.add(albumId);
      _partial[albumId] = current;
    }
    notifyListeners();
  }

  int get albumCount => _selected.length;

  int pickedCount(String id) {
    if (!_selected.contains(id)) return 0;
    final album = albums.firstWhere((a) => a.id == id);
    return _partial[id]?.length ?? album.count;
  }

  void setAlbum(String id, bool on) {
    on ? _selected.add(id) : _selected.remove(id);
    _partial.remove(id);
    notifyListeners();
  }

  int get trackCount {
    var n = 0;
    for (final a in albums) {
      if (!_selected.contains(a.id)) continue;
      n += _partial[a.id]?.length ?? a.count;
    }
    return n;
  }

  bool get everything => _selected.length == albums.length && _partial.isEmpty;

  bool get nothing => _selected.isEmpty;

  List<Map<String, Object?>> selection() => [
        for (final a in albums)
          if (_selected.contains(a.id))
            {
              'album': a.id,
              if (_partial[a.id] case final ids?) 'tracks': ids.toList(),
            },
      ];
}
