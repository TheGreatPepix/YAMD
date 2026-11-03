import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/core.dart';
import '../desktop.dart';
import 'draft.dart';
import 'models.dart';
import 'picker.dart';
import 'search.dart';

class Controller extends ChangeNotifier {
  Controller(this.core, {Desktop? desktop}) : desktop = desktop ?? Desktop() {
    _sub = core.events.listen(_receive);
    this.desktop.listen(exit: _trayExit);
  }

  final Core core;
  final Desktop desktop;
  late final StreamSubscription<Event> _sub;

  final _notices = StreamController<Notice>.broadcast();
  Stream<Notice> get notices => _notices.stream;

  final _updateOffers = StreamController<UpdateInfo>.broadcast();
  Stream<UpdateInfo> get updateOffers => _updateOffers.stream;

  final _exitRequests = StreamController<void>.broadcast();
  Stream<void> get exitRequests => _exitRequests.stream;

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
  late final search = SearchState(send);

  final _jobs = <int, Job>{};
  List<Job> get jobs => _jobs.values.toList().reversed.toList();

  final stats = ValueNotifier(const Stats());

  final log = ValueNotifier('');

  bool get canDownload => account.status == AccountStatus.ok;

  bool get downloading => _jobs.values.any((j) => !j.finished);

  int get running => _jobs.values.where((j) => !j.finished).length;

  void restart() => desktop.restart();

  void _trayExit() {
    if (!downloading) {
      quit();
      return;
    }
    desktop.showWindow();
    _exitRequests.add(null);
  }

  void quit() {
    if (fatal != null) {
      desktop.quit();
    } else {
      send({'cmd': 'exit'});
    }
  }

  void start() => send({'cmd': 'ready'});

  void send(Map<String, Object?> command) => core.send(command);

  void login(String token) => send({'cmd': 'login', 'token': token.trim()});

  void recheck() => send({'cmd': 'recheck'});

  void logout() {
    search.close();
    _dropDrafts();
    send({'cmd': 'logout'});
  }

  Draft _newDraft(String link) {
    send({'cmd': 'preview', 'link': link});
    return Draft(link);
  }

  int addLinks(String text) {
    final list = List.of(drafts.value);
    var added = 0;
    Draft? first, existing;
    for (final link in splitLinks(text)) {
      final known = list.where((d) => d.link == link).firstOrNull;
      if (known != null) {
        existing ??= known;
        continue;
      }
      final d = _newDraft(link);
      first ??= d;
      list.add(d);
      added++;
    }
    if (added > 0) {
      drafts.value = list;
      selected.value = first;
    } else if (existing != null) {
      selected.value = existing;
      _notices.add(const Notice('Уже в подборке, открыл её'));
    }
    return added;
  }

  Draft? draftFor(String link) => drafts.value.where((d) => d.link == link).firstOrNull;

  void toggleHit(SearchHit hit) {
    final known = draftFor(hit.link);
    if (known != null) {
      removeDraft(known);
      return;
    }
    final d = _newDraft(hit.link);
    drafts.value = [...drafts.value, d];
    selected.value = d;
  }

  List<Draft> _trash = const [];

  void _flushTrash() {
    for (final d in _trash) {
      d.dispose();
    }
    _trash = const [];
  }

  void _discard(List<Draft> removed, String message) {
    final before = drafts.value;
    final was = selected.value;
    _flushTrash();
    _trash = removed;
    final next = [
      for (final x in before)
        if (!removed.contains(x)) x,
    ];
    drafts.value = next;
    if (was == null || removed.contains(was)) {
      final i = was == null ? 0 : before.indexOf(was);
      selected.value = next.isEmpty ? null : next[i.clamp(0, next.length - 1)];
    }
    _notices.add(Notice(message, action: 'Вернуть', onAction: () => _restore(removed, before, was)));
  }

  void _restore(List<Draft> removed, List<Draft> before, Draft? was) {
    if (!identical(_trash, removed)) return;
    _trash = const [];
    final current = drafts.value;
    final links = {for (final d in current) d.link};
    final back = [
      for (final d in removed)
        if (!links.contains(d.link)) d,
    ];
    for (final d in removed) {
      if (!back.contains(d)) d.dispose();
    }
    drafts.value = [
      for (final d in before)
        if (back.contains(d) || current.contains(d)) d,
      for (final d in current)
        if (!before.contains(d)) d,
    ];
    selected.value = back.contains(was) ? was : (back.firstOrNull ?? selected.value);
  }

  void removeDraft(Draft d) => _discard([d], 'Убрано из подборки');

  void clearDrafts() {
    if (drafts.value.isEmpty) return;
    _discard(List.of(drafts.value), 'Подборка очищена');
  }

  void _take(Draft d) {
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

  void _dropDrafts() {
    final old = drafts.value;
    drafts.value = const [];
    selected.value = null;
    _flushTrash();
    for (final d in old) {
      d.dispose();
    }
  }

  void downloadDraft(Draft d) {
    if (!d.ready) return;
    final select = d.selection;
    send({'cmd': 'download', 'link': d.link, if (select != null) 'select': select});
    _take(d);
    downloadsOpen.value = true;
  }

  void downloadAll() {
    for (final d in List.of(drafts.value)) {
      if (d.ready) downloadDraft(d);
    }
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

        for (final d in [...drafts.value, ..._trash]) {
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
      case 'search':
        search.receive(ev);
        return;
      case 'albumTracks':
        final id = '${ev['id']}';
        final tracks = [
          for (final t in (ev['tracks'] as List? ?? const []))
            if (t is Map<String, dynamic>) TrackOption.fromJson(t),
        ];
        for (final d in [...drafts.value, ..._trash]) {
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
    _exitRequests.close();
    updateProgress.dispose();
    for (final j in _jobs.values) {
      j.dispose();
    }
    for (final d in [...drafts.value, ..._trash]) {
      d.dispose();
    }
    search.dispose();
    drafts.dispose();
    selected.dispose();
    downloadsOpen.dispose();
    stats.dispose();
    log.dispose();
    super.dispose();
  }
}
