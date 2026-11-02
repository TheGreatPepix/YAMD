import 'dart:async';

import 'core.dart';

class FakeCore implements Core {
  FakeCore({this.tick = const Duration(milliseconds: 120)});

  final Duration tick;
  final _events = StreamController<Event>();
  final _timers = <Timer>{};
  final _jobs = <int, _FakeJob>{};
  var _nextId = 0;
  Timer? _ticker;

  var _dir = r'C:\Users\user\Music\Yandex Music Downloads';
  var _theme = 'dark';
  var _quality = 'lossless';
  var _concurrency = 4;
  var _plus = false;
  Map<String, Object?>? lastDownload;

  static const _albums = [
    {'id': '10', 'title': 'Группа крови', 'year': 1988, 'count': 11, 'type': 'album'},
    {'id': '11', 'title': 'Звезда по имени Солнце', 'year': 1989, 'count': 10, 'type': 'album'},
    {'id': '12', 'title': 'Кукушка', 'year': 1990, 'count': 1, 'type': 'single'},
    {'id': '13', 'title': 'Последний герой', 'year': 1989, 'count': 11, 'type': 'compilation'},
  ];

  @override
  Stream<Event> get events => _events.stream;

  void _emit(Event e) {
    if (!_events.isClosed) scheduleMicrotask(() => _events.add(e));
  }

  void _later(Duration d, void Function() f) {
    late final Timer t;
    t = Timer(d, () {
      _timers.remove(t);
      f();
    });
    _timers.add(t);
  }

  Map<String, Object?> _state() => {
        'type': 'state',
        'dir': _dir,
        'theme': _theme,
        'quality': _quality,
        'concurrency': _concurrency,
        'version': '2.0.1',
      };

  @override
  void send(Map<String, Object?> c) {
    switch (c['cmd']) {
      case 'ready':
        _emit(_state());
        _emit({'type': 'account', 'status': 'none'});
      case 'login':
        final token = '${c['token']}';
        _emit({'type': 'account', 'status': 'checking'});
        _later(const Duration(milliseconds: 500), () {
          _plus = token != 'bad' && token != 'noplus';
          _emit(switch (token) {
            'bad' => {
                'type': 'account',
                'status': 'error',
                'message': 'токен недействителен или устарел, получите новый',
              },
            'noplus' => {
                'type': 'account',
                'status': 'noplus',
                'login': 'ivan.petrov',
                'name': 'Иван Петров',
                'hasPlus': false,
                'message': 'для скачивания нужна активная подписка Яндекс Плюс',
              },
            _ => {
                'type': 'account',
                'status': 'ok',
                'login': 'ivan.petrov',
                'name': 'Иван Петров',
                'hasPlus': true,
              },
          });
        });
      case 'recheck' when _plus:
        _later(const Duration(milliseconds: 300), () {
          _emit({
            'type': 'account',
            'status': 'ok',
            'login': 'ivan.petrov',
            'name': 'Иван Петров',
            'hasPlus': true
          });
          _emit({'type': 'notice', 'kind': 'ok', 'message': 'Подписка Плюс активна'});
        });
      case 'recheck':
        _emit({'type': 'account', 'status': 'checking', 'login': 'ivan.petrov'});
        _later(const Duration(milliseconds: 400), () {
          _emit({
            'type': 'account',
            'status': 'ok',
            'login': 'ivan.petrov',
            'name': 'Иван Петров',
            'hasPlus': true
          });
        });
      case 'logout':
        _plus = false;
        for (final j in _jobs.values) {
          j.cancelled = true;
        }
        _emit({'type': 'account', 'status': 'none'});
      case 'prefs':
        if (c['dir'] case final String d when d.isNotEmpty) _dir = d;
        if (c['theme'] case final String t when t.isNotEmpty) _theme = t;
        if (c['quality'] case final String q when q.isNotEmpty) _quality = q;
        if (c['concurrency'] case final int n when n > 0) _concurrency = n;
        _emit(_state());
      case 'preview':
        _preview('${c['link']}');
      case 'download':
        lastDownload = c;
        _download('${c['link']}', c['select'] as List?);
      case 'album':
        final id = '${c['album']}';
        final count = _albumCount(id);
        _later(const Duration(milliseconds: 200), () {
          _emit({
            'type': 'albumTracks',
            'id': id,
            'tracks': [
              for (var i = 0; i < count; i++)
                {
                  'id': '$id${i + 1}',
                  'title': _titles[i % _titles.length],
                  'artist': 'Кино',
                  'number': i + 1,
                  'explicit': i.isOdd,
                },
            ],
          });
        });
      case 'cancel':
        final id = c['id'] as int? ?? 0;
        for (final j in _jobs.values) {
          if (id == 0 || j.id == id) j.cancelled = true;
        }
      case 'retry':
        final j = _jobs.remove(c['id']);
        if (j != null) {
          _emit({'type': 'jobRemoved', 'id': j.id});
          _download(j.link, null);
        }
      case 'remove':
        final id = c['id'] as int? ?? 0;
        _jobs.removeWhere((k, j) {
          final drop = (id == 0 || k == id) && j.finished;
          if (drop) _emit({'type': 'jobRemoved', 'id': k});
          return drop;
        });
      case 'exit':
        _emit({'type': 'exit'});
    }
  }

  static (String, String, String, int, int) _release(String link) {
    if (link.contains('/artist/')) return ('artist', 'Кино', 'Кино', 0, 12);
    if (link.contains('/playlists/')) return ('playlist', 'Плейлист дня', 'Иван Петров', 0, 6);
    if (link.contains('/track/')) return ('track', 'Кукушка', 'Кино', 1990, 1);
    return ('album', 'Группа крови', 'Кино', 1988, 8);
  }

  static const _titles = [
    'Группа крови',
    'Закрой за мной дверь, я ухожу',
    'Война',
    'Спокойная ночь',
    'Мама, мы все тяжело больны',
    'Кукушка',
    'Звезда по имени Солнце',
    'Пачка сигарет',
    'Хочу перемен!',
    'Апрельская',
    'Легенда',
    'Печаль',
  ];

  void _preview(String link) {
    if (link.isEmpty) return;
    if (!link.contains('yandex') && int.tryParse(link) == null) {
      _emit({
        'type': 'preview',
        'link': link,
        'status': 'error',
        'message': 'Не удалось распознать ссылку.',
      });
      return;
    }
    final (kind, title, artist, year, count) = _release(link);
    _emit({'type': 'preview', 'link': link, 'status': 'loading', 'kind': kind});
    _later(const Duration(milliseconds: 300), () {
      _emit({
        'type': 'preview',
        'link': link,
        'status': 'ok',
        'kind': kind,
        'title': title,
        'artist': artist,
        'year': year,
        'cover': '',
        'count': count,
        'folder': kind == 'track' ? '' : (kind == 'album' ? '$artist - $title ($year)' : title),
        if (kind == 'artist') 'albums': _albums,
        if (kind == 'album') ...{
          'explicit': true,
          'albums': [
            {
              'id': _albumId(link),
              'title': title,
              'year': year,
              'count': count,
              'type': 'album',
              'explicit': true
            },
          ],
        },
      });
    });
  }

  static String _albumId(String link) => RegExp('/album/([0-9]+)').firstMatch(link)?.group(1) ?? '0';

  static int _albumCount(String id) =>
      (_albums.where((a) => a['id'] == id).firstOrNull?['count'] as int?) ?? 8;

  void _download(String link, List? select) {
    var (kind, title, artist, year, count) = _release(link);
    if (select != null) {
      count = 0;
      for (final s in select.cast<Map>()) {
        final tracks = s['tracks'] as List?;
        count += tracks?.length ?? _albumCount('${s['album']}');
      }
    }
    final j = _FakeJob(++_nextId, link, kind, title, artist, year, count);
    _jobs[j.id] = j;
    _emit(j.event());
    _later(const Duration(milliseconds: 300), () {
      j.status = 'running';
      j.tracks = [
        for (var i = 0; i < count; i++)
          {
            'i': i,
            'title': _titles[i % _titles.length],
            'artist': artist,
            'status': 'queued',
            'done': 0,
            'size': 28000000 + i * 3100000,
          },
      ];
      _emit(j.event(full: true));
      _ticker ??= Timer.periodic(tick, (_) => _step());
    });
  }

  void _step() {
    var active = 0, queued = 0;
    var speed = 0.0;
    final running = _jobs.values.where((j) => !j.finished).toList();
    var slots = _concurrency;
    for (final j in running) {
      if (j.cancelled) {
        for (final t in j.tracks) {
          if (t['status'] == 'queued' || t['status'] == 'active') t['status'] = 'cancelled';
        }
        j.status = 'cancelled';
        j.message = 'Остановлено';
        _emit(j.event(full: true));
        continue;
      }
      for (final t in j.tracks) {
        if (t['status'] == 'active' || (t['status'] == 'queued' && slots > 0)) {
          if (slots <= 0) break;
          slots--;
          t['status'] = 'active';
          final size = t['size'] as int;
          final done = ((t['done'] as int) + 6000000).clamp(0, size);
          t['done'] = done;
          speed += 6000000 * 1000 / tick.inMilliseconds;
          if (done >= size) {
            t['status'] = 'done';
            t['format'] = (t['i'] as int).isEven ? 'FLAC 24/96' : 'FLAC 16/44.1';
          }
        }
      }
      active += j.tracks.where((t) => t['status'] == 'active').length;
      queued += j.tracks.where((t) => t['status'] == 'queued').length;
      if (j.tracks.every((t) => t['status'] == 'done')) {
        j.status = 'done';
        j.message = 'Скачано ${j.tracks.length}';
        _emit({'type': 'notice', 'kind': 'ok', 'message': '${j.title}: ${j.message}'});
      }
      _emit(j.event(full: true));
    }
    _emit({'type': 'stats', 'speed': speed, 'active': active, 'queued': queued});
    if (_jobs.values.every((j) => j.finished)) {
      _ticker?.cancel();
      _ticker = null;
      _emit({'type': 'stats', 'speed': 0, 'active': 0, 'queued': 0});
    }
  }

  @override
  Future<void> close() async {
    _ticker?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    await _events.close();
  }
}

class _FakeJob {
  _FakeJob(this.id, this.link, this.kind, this.title, this.artist, this.year, this.count);

  final int id, year, count;
  final String link, kind, title, artist;
  var status = 'resolving';
  var message = '';
  var cancelled = false;
  List<Map<String, Object?>> tracks = [];

  bool get finished => status == 'done' || status == 'error' || status == 'cancelled';

  Event event({bool full = false}) => {
        'type': 'job',
        'id': id,
        'link': link,
        'kind': kind,
        'title': status == 'resolving' ? '' : title,
        'artist': artist,
        'year': year,
        'cover': '',
        'dir': r'C:\Users\user\Music\Yandex Music Downloads',
        'status': status,
        'message': message,
        'total': tracks.length,
        'full': full,
        'tracks': full ? tracks.map(Map.of).toList() : const [],
      };
}
