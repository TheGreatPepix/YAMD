import 'package:flutter/foundation.dart';

import 'picker.dart';

int _int(Object? v) => v is num ? v.toInt() : 0;
String _str(Object? v) => v == null ? '' : '$v';

enum ThemeChoice { system, light, dark }

enum Quality { lossless, mp3 }

enum AccountStatus { none, checking, ok, noplus, error }

class Account {
  const Account({
    this.status = AccountStatus.none,
    this.login = '',
    this.name = '',
    this.hasPlus = false,
    this.message = '',
  });

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        status: AccountStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => AccountStatus.none,
        ),
        login: _str(j['login']),
        name: _str(j['name']),
        hasPlus: j['hasPlus'] == true,
        message: _str(j['message']),
      );

  final AccountStatus status;
  final String login, name, message;
  final bool hasPlus;

  String get displayName => name.isNotEmpty ? name : login;
  String get initial =>
      displayName.isEmpty ? '?' : String.fromCharCode(displayName.runes.first).toUpperCase();
}

enum ReleaseKind {
  track('Трек', 'Скачать трек'),
  album('Альбом', 'Скачать альбом'),
  playlist('Плейлист', 'Скачать плейлист'),
  artist('Исполнитель', 'Скачать дискографию');

  const ReleaseKind(this.label, this.action);
  final String label, action;

  static ReleaseKind parse(Object? v) =>
      ReleaseKind.values.firstWhere((k) => k.name == v, orElse: () => ReleaseKind.track);
}

enum PreviewStatus { loading, ok, error }

class Preview {
  const Preview({
    required this.link,
    required this.status,
    this.kind = ReleaseKind.track,
    this.title = '',
    this.artist = '',
    this.year = 0,
    this.cover = '',
    this.count = 0,
    this.folder = '',
    this.message = '',
    this.albums = const [],
    this.explicit = false,
  });

  factory Preview.fromJson(Map<String, dynamic> j) => Preview(
        link: _str(j['link']),
        status: PreviewStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => PreviewStatus.error,
        ),
        kind: ReleaseKind.parse(j['kind']),
        title: _str(j['title']),
        artist: _str(j['artist']),
        year: _int(j['year']),
        cover: _str(j['cover']),
        count: _int(j['count']),
        folder: _str(j['folder']),
        message: _str(j['message']),
        explicit: j['explicit'] == true,
        albums: [
          for (final a in (j['albums'] as List? ?? const []))
            if (a is Map<String, dynamic>) AlbumOption.fromJson(a),
        ],
      );

  final String link, title, artist, cover, folder, message;
  final PreviewStatus status;
  final ReleaseKind kind;
  final int year, count;
  final List<AlbumOption> albums;
  final bool explicit;
}

enum TrackStatus { queued, active, done, skipped, error, cancelled }

class TrackItem {
  TrackItem.fromJson(Map<String, dynamic> j)
      : index = _int(j['i']),
        title = _str(j['title']),
        artist = _str(j['artist']),
        status = TrackStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => TrackStatus.queued,
        ),
        done = _int(j['done']),
        size = _int(j['size']),
        format = _str(j['format']),
        message = _str(j['message']),
        path = _str(j['path']),
        explicit = j['explicit'] == true;

  final int index, done, size;
  final String title, artist, format, message, path;
  final TrackStatus status;
  final bool explicit;

  bool get finished =>
      status == TrackStatus.done ||
      status == TrackStatus.skipped ||
      status == TrackStatus.error ||
      status == TrackStatus.cancelled;

  double? get fraction => size > 0 ? (done / size).clamp(0.0, 1.0) : null;
}

enum JobStatus { resolving, running, done, error, cancelled }

class Job extends ChangeNotifier {
  Job(this.id);

  final int id;
  var link = '';
  var kind = ReleaseKind.track;
  var title = '';
  var artist = '';
  var year = 0;
  var cover = '';
  var dir = '';
  var status = JobStatus.resolving;
  var message = '';
  var total = 0;
  var explicit = false;
  List<TrackItem> tracks = const [];

  bool get finished => status == JobStatus.done || status == JobStatus.error || status == JobStatus.cancelled;

  int count(TrackStatus s) => tracks.where((t) => t.status == s).length;

  int get completed => tracks.where((t) => t.finished).length;

  int get failed => count(TrackStatus.error);

  double? get fraction {
    if (status == JobStatus.resolving) return null;
    if (tracks.isEmpty) return finished ? 1 : null;
    var sum = 0.0;
    for (final t in tracks) {
      if (t.finished) {
        sum += 1;
      } else if (t.status == TrackStatus.active) {
        sum += t.fraction ?? 0;
      }
    }
    return (sum / tracks.length).clamp(0.0, 1.0);
  }

  Set<String> get formats => {
        for (final t in tracks)
          if (t.format.isNotEmpty) t.format
      };

  void apply(Map<String, dynamic> j) {
    link = _str(j['link']);
    kind = ReleaseKind.parse(j['kind']);
    title = _str(j['title']);
    artist = _str(j['artist']);
    year = _int(j['year']);
    cover = _str(j['cover']);
    dir = _str(j['dir']);
    status = JobStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => JobStatus.resolving,
    );
    message = _str(j['message']);
    total = _int(j['total']);
    explicit = j['explicit'] == true;

    final raw = (j['tracks'] as List?)?.whereType<Map<String, dynamic>>() ?? const [];
    final items = raw.map(TrackItem.fromJson);
    if (j['full'] == true) {
      tracks = items.toList();
    } else if (items.isNotEmpty) {
      final next = List.of(tracks);
      for (final t in items) {
        if (t.index >= 0 && t.index < next.length) next[t.index] = t;
      }
      tracks = next;
    }
    notifyListeners();
  }
}

class Stats {
  const Stats({this.speed = 0, this.active = 0, this.queued = 0});

  Stats.fromJson(Map<String, dynamic> j)
      : speed = (j['speed'] as num?)?.toDouble() ?? 0,
        active = _int(j['active']),
        queued = _int(j['queued']);

  final double speed;
  final int active, queued;

  bool get busy => active > 0 || queued > 0;
}

class Notice {
  const Notice(this.message, {this.kind = NoticeKind.info});

  final String message;
  final NoticeKind kind;
}

enum NoticeKind { info, ok, error }

String formatBytes(num n) {
  const k = 1024.0, m = k * 1024, g = m * 1024;
  if (n < k) return '${n.round()} Б';
  if (n < m) return '${(n / k).toStringAsFixed(1)} КБ';
  if (n < g) return '${(n / m).toStringAsFixed(1)} МБ';
  return '${(n / g).toStringAsFixed(2)} ГБ';
}

String tracksLabel(int n) {
  final mod10 = n % 10, mod100 = n % 100;
  final word = (mod10 == 1 && mod100 != 11)
      ? 'трек'
      : (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
          ? 'трека'
          : 'треков';
  return '$n $word';
}
