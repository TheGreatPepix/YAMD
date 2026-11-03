import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/core.dart';
import '../desktop.dart';
import 'draft.dart';
import 'models.dart';
import 'picker.dart';

class Controller extends ChangeNotifier {
  Controller(this.core, {Desktop? desktop}) : desktop = desktop ?? Desktop() {
    _sub = core.events.listen(_receive);
  }

  final Core core;
  final Desktop desktop;
  late final StreamSubscription<Event> _sub;

  final _notices = StreamController<Notice>.broadcast();
  Stream<Notice> get notices => _notices.stream;

  final _updateOffers = StreamController<UpdateInfo>.broadcast();
  Stream<UpdateInfo> get updateOffers => _updateOffers.stream;

  var ready = false;
  String? fatal;

  var account = const Account();
  var dir = '';
  var theme = ThemeChoice.dark;
  var quality = Quality.lossless;
  var concurrency = 4;
  var version = '';

  UpdateInfo? update;
  var checkingUpdate = false;
  var updating = false;
  final updateProgress = ValueNotifier<double?>(null);

  final drafts = ValueNotifier<List<Draft>>(const []);
  final selected = ValueNotifier<Draft?>(null);
  final downloadsOpen = ValueNotifier(false);

  final _jobs = <int, Job>{};
  List<Job> get jobs => _jobs.values.toList().reversed.toList();

  final stats = ValueNotifier(const Stats());

  final log = ValueNotifier('');

  bool get canDownload => account.status == AccountStatus.ok;

  bool get downloading => _jobs.values.any((j) => !j.finished);

  void start() => send({'cmd': 'ready'});

  void send(Map<String, Object?> command) => core.send(command);

  void login(String token) => send({'cmd': 'login', 'token': token.trim()});

  void recheck() => send({'cmd': 'recheck'});

  void logout() {
    clearDrafts();
    send({'cmd': 'logout'});
  }

  int addLinks(String text) {
    final list = List.of(drafts.value);
    var added = 0;
    Draft? first;
    for (final link in splitLinks(text)) {
      if (list.any((d) => d.link == link)) continue;
      final d = Draft(link);
      first ??= d;
      list.add(d);
      added++;
      send({'cmd': 'preview', 'link': link});
    }
    if (added > 0) {
      drafts.value = list;
      selected.value = first;
    } else if (text.trim().isNotEmpty) {
      _notices.add(const Notice('Эти ссылки уже в подборке'));
    }
    return added;
  }

  void removeDraft(Draft d) {
    final old = drafts.value;
    final i = old.indexOf(d);
    final next = [
      for (final x in old)
        if (x != d) x,
    ];
    drafts.value = next;
    if (selected.value == d) {
      selected.value = next.isEmpty ? null : next[i.clamp(0, next.length - 1)];
    }
    d.dispose();
  }

  void clearDrafts() {
    final old = drafts.value;
    drafts.value = const [];
    selected.value = null;
    for (final d in old) {
      d.dispose();
    }
  }

  void downloadDraft(Draft d) {
    if (!d.ready) return;
    final select = d.selection;
    send({'cmd': 'download', 'link': d.link, if (select != null) 'select': select});
    removeDraft(d);
  }

  void downloadAll() {
    var sent = false;
    for (final d in List.of(drafts.value)) {
      if (!d.ready) continue;
      downloadDraft(d);
      sent = true;
    }
    if (sent) downloadsOpen.value = true;
  }

  void _loadAlbum(String id) => send({'cmd': 'album', 'album': id});

  void cancel(int id) => send({'cmd': 'cancel', 'id': id});

  void cancelAll() => send({'cmd': 'cancel', 'id': 0});

  void retry(int id) => send({'cmd': 'retry', 'id': id});

  void remove(int id) => send({'cmd': 'remove', 'id': id});

  void clearFinished() => send({'cmd': 'remove', 'id': 0});

  void setTheme(ThemeChoice t) {
    theme = t;
    send({'cmd': 'prefs', 'theme': t.name});
    notifyListeners();
  }

  void setDir(String d) {
    dir = d;
    send({'cmd': 'prefs', 'dir': d});
    notifyListeners();
  }

  void setQuality(Quality q) {
    quality = q;
    send({'cmd': 'prefs', 'quality': q.name});
    notifyListeners();
  }

  void setConcurrency(int n) {
    concurrency = n;
    send({'cmd': 'prefs', 'concurrency': n});
    notifyListeners();
  }

  void checkUpdate() {
    checkingUpdate = true;
    send({'cmd': 'checkUpdate'});
    notifyListeners();
  }

  void applyUpdate() {
    if (updating) return;
    updating = true;
    updateProgress.value = null;
    send({'cmd': 'applyUpdate'});
    notifyListeners();
  }

  void _onUpdate(UpdateInfo u) {
    checkingUpdate = false;
    update = u;
    if (u.quiet) {
      if (u.available) _updateOffers.add(u);
    } else if (u.error.isNotEmpty) {
      _notices.add(Notice('Не удалось проверить обновления: ${u.error}', kind: NoticeKind.error));
    } else if (!u.available) {
      _notices.add(Notice('У вас последняя версия ${u.current}', kind: NoticeKind.ok));
    }
  }

  void _onUpdating(Event ev) {
    final error = ev['error'];
    if (error != null) {
      updating = false;
      updateProgress.value = null;
      _notices.add(Notice('Не удалось обновить YAMD: $error', kind: NoticeKind.error));
      return;
    }
    updating = true;
    final done = (ev['done'] as num?)?.toDouble() ?? 0;
    final total = (ev['total'] as num?)?.toDouble() ?? 0;
    updateProgress.value = total > 0 ? (done / total).clamp(0.0, 1.0) : null;
  }

  void openFolder(String path) => desktop.open(path);

  void reveal(String file) => desktop.reveal(file);

  void openLink(String url) => desktop.open(url);

  void clearLog() => log.value = '';

  void _appendLog(String text) {
    var s = log.value + text;
    const limit = 200000;
    if (s.length > limit) {
      var cut = s.length - limit * 3 ~/ 4;
      final nl = s.indexOf('\n', cut);
      if (nl >= 0) cut = nl + 1;
      s = s.substring(cut);
    }
    log.value = s;
  }

  void _receive(Event ev) {
    switch (ev['type']) {
      case 'state':
        dir = '${ev['dir'] ?? ''}';
        theme = switch ('${ev['theme']}') {
          'light' => ThemeChoice.light,
          'dark' => ThemeChoice.dark,
          _ => ThemeChoice.system,
        };
        quality = ev['quality'] == 'mp3' ? Quality.mp3 : Quality.lossless;
        concurrency = (ev['concurrency'] as num?)?.toInt() ?? concurrency;
        version = '${ev['version'] ?? ''}';
        if (ev['log'] is String) log.value = ev['log'] as String;
        ready = true;
      case 'account':
        account = Account.fromJson(ev);
      case 'preview':
        final p = Preview.fromJson(ev);

        for (final d in drafts.value) {
          if (d.link == p.link) d.apply(p, _loadAlbum);
        }
        return;
      case 'job':
        final id = (ev['id'] as num).toInt();
        final existing = _jobs[id];
        if (existing != null) {
          existing.apply(ev);
          return;
        }
        _jobs[id] = Job(id)..apply(ev);
      case 'jobRemoved':
        _jobs.remove((ev['id'] as num).toInt())?.dispose();
      case 'albumTracks':
        final id = '${ev['id']}';
        final tracks = [
          for (final t in (ev['tracks'] as List? ?? const []))
            if (t is Map<String, dynamic>) TrackOption.fromJson(t),
        ];
        for (final d in drafts.value) {
          final p = d.picker;
          if (p == null || !p.isLoading(id)) continue;
          ev['error'] != null ? p.setError(id, '${ev['error']}') : p.setTracks(id, tracks);
        }
        return;
      case 'stats':
        stats.value = Stats.fromJson(ev);
        return;
      case 'log':
        _appendLog('${ev['text'] ?? ''}');
        return;
      case 'notice':
        _notices.add(
          Notice(
            '${ev['message'] ?? ''}',
            kind: switch (ev['kind']) {
              'error' => NoticeKind.error,
              'ok' => NoticeKind.ok,
              _ => NoticeKind.info,
            },
          ),
        );
        return;
      case 'update':
        _onUpdate(UpdateInfo.fromJson(ev));
      case 'updating':
        final was = updating;
        _onUpdating(ev);
        if (was == updating) return;
      case 'exit':
        desktop.quit();
        return;
      case 'fatal':
        fatal = '${ev['message'] ?? ''}';
      case 'coreExited':
        fatal ??= 'Ядро остановилось (код ${ev['code']}).';
      default:
        return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    _notices.close();
    _updateOffers.close();
    updateProgress.dispose();
    for (final j in _jobs.values) {
      j.dispose();
    }
    for (final d in drafts.value) {
      d.dispose();
    }
    drafts.dispose();
    selected.dispose();
    downloadsOpen.dispose();
    stats.dispose();
    log.dispose();
    super.dispose();
  }
}
