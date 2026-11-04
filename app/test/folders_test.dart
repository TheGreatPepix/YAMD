import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ymd/core/fake_core.dart';
import 'package:ymd/desktop.dart';
import 'package:ymd/state/controller.dart';
import 'package:ymd/state/models.dart';

class _Desktop extends Desktop {
  _Desktop({this.picked, this.error, this.opens = true});

  final String? picked;
  final PlatformException? error;
  final bool opens;
  final asked = <String>[];

  @override
  Future<String?> pickFolder(String current) async {
    asked.add(current);
    if (error != null) throw error!;
    return picked;
  }

  @override
  Future<bool> open(String target) async => opens;

  @override
  Future<bool> reveal(String file) async => opens;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(Controller, List<Notice>)> make(_Desktop d) async {
    final c = Controller(FakeCore(), desktop: d);
    final notices = <Notice>[];
    c.notices.listen(notices.add);
    c.dir = '/music';
    return (c, notices);
  }

  test('выбранная папка сохраняется, отмена ничего не меняет', () async {
    final d = _Desktop(picked: '/storage/emulated/0/Music/YAMD');
    final (c, _) = await make(d);
    await c.chooseDir();
    expect(d.asked, ['/music']);
    expect(c.dir, '/storage/emulated/0/Music/YAMD');

    final (c2, notices) = await make(_Desktop());
    await c2.chooseDir();
    expect(c2.dir, '/music');
    expect(notices, isEmpty);
  });

  test('ошибка выбора папки показывается как есть', () async {
    final (c, notices) = await make(
      _Desktop(error: PlatformException(code: 'unsupported', message: 'Эту папку нельзя выбрать')),
    );
    await c.chooseDir();
    await Future<void>.delayed(Duration.zero);
    expect(c.dir, '/music');
    expect(notices.single.message, 'Эту папку нельзя выбрать');
    expect(notices.single.kind, NoticeKind.error);
  });

  test('если папку нечем открыть, подсказывает путь', () async {
    final (c, notices) = await make(_Desktop(opens: false));
    await c.openFolder('/music/Альбом');
    await c.reveal('/music/Альбом/01.flac');
    await Future<void>.delayed(Duration.zero);
    expect(notices.map((n) => n.message), [
      'Не нашлось приложения, чтобы открыть папку. Файлы лежат здесь: /music/Альбом',
      'Не нашлось приложения, чтобы открыть папку. Файлы лежат здесь: /music/Альбом/01.flac',
    ]);

    final (ok, quiet) = await make(_Desktop());
    await ok.openFolder('/music');
    await Future<void>.delayed(Duration.zero);
    expect(quiet, isEmpty);
  });
}
