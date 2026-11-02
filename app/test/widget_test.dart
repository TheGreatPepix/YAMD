import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ymd/app.dart';
import 'package:ymd/core/fake_core.dart';
import 'package:ymd/state/controller.dart';
import 'package:ymd/state/models.dart';

Future<(FakeCore, Controller)> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final core = FakeCore();
  final controller = Controller(core);
  await tester.pumpWidget(YmdApp(controller: controller));
  await tester.pumpAndSettle();
  return (core, controller);
}

Future<void> _login(WidgetTester tester, String token) async {
  await tester.enterText(find.byType(TextField), token);
  await tester.tap(find.text('Войти'));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

Future<void> _add(WidgetTester tester, String links) async {
  await tester.enterText(find.byType(TextField), links);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('без входа виден только экран входа', (tester) async {
    final (core, c) = await _open(tester);

    expect(c.ready, isTrue);
    expect(c.version, '2.0.0');
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Подборка'), findsNothing);

    await core.close();
  });

  testWidgets('без Плюса скачивание недоступно', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'noplus');

    expect(c.account.status, AccountStatus.noplus);
    expect(c.canDownload, isFalse);
    expect(find.text('Оформить Плюс'), findsOneWidget);
    expect(find.text('Подборка'), findsNothing);

    await core.close();
  });

  testWidgets('неверный токен показывает ошибку', (tester) async {
    final (core, _) = await _open(tester);
    await _login(tester, 'bad');

    expect(find.textContaining('недействителен'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);

    await core.close();
  });

  testWidgets('с Плюсом: ссылка определяется и альбом качается', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'good-token');

    expect(c.canDownload, isTrue);
    expect(find.text('Подборка'), findsOneWidget);
    expect(find.text('Плюс'), findsOneWidget);

    await _add(tester, 'https://music.yandex.ru/album/123');

    expect(find.text('Группа крови'), findsOneWidget);
    expect(find.text('Кино · 8 треков'), findsOneWidget);
    expect(find.text('1 ссылка · 8 треков'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Скачать'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(c.drafts.value, isEmpty);
    expect(c.jobs, hasLength(1));
    expect(c.jobs.first.tracks, hasLength(8));

    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump();
    expect(c.jobs.first.count(TrackStatus.active), 4);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(c.jobs.first.status, JobStatus.done);
    expect(c.jobs.first.formats, containsAll(['FLAC 24/96', 'FLAC 16/44.1']));

    await core.close();
  });

  testWidgets('пачка разных ссылок собирается в подборку и качается разом', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'good-token');

    await _add(
      tester,
      'https://music.yandex.ru/album/123 https://music.yandex.ru/album/1/track/5, '
      'https://music.yandex.ru/users/me/playlists/3 https://example.com/x',
    );

    expect(c.drafts.value, hasLength(4));
    expect(find.text('Кукушка'), findsOneWidget);
    expect(find.text('Плейлист дня'), findsOneWidget);
    expect(find.text('Не удалось распознать ссылку.'), findsOneWidget);
    expect(find.text('3 ссылки · 15 треков'), findsOneWidget);

    await _add(tester, 'https://music.yandex.ru/album/123');
    expect(c.drafts.value, hasLength(4));

    await tester.tap(find.text('Скачать всё'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(c.jobs, hasLength(3));
    expect(c.drafts.value, hasLength(1));

    await tester.pumpAndSettle(const Duration(seconds: 10));
    await core.close();
  });

  testWidgets('проверка подписки не уводит с главного экрана', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'good-token');

    await tester.tap(find.text('Иван Петров'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверить подписку'));
    await tester.pump();
    expect(find.text('Подборка'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(c.canDownload, isTrue);
    expect(find.text('Подборка'), findsOneWidget);
    expect(find.text('Подписка Плюс активна'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 5));
    await core.close();
  });

  testWidgets('у исполнителя можно выбрать альбомы и треки', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'good-token');

    await _add(tester, 'https://music.yandex.ru/artist/1');
    expect(find.text('Вся дискография · 33 трека'), findsOneWidget);

    await tester.tap(find.text('Выбрать релизы'));
    await tester.pumpAndSettle();
    expect(find.text('Альбомы'), findsOneWidget);
    expect(find.text('Синглы и EP'), findsOneWidget);
    expect(find.text('Сборники'), findsOneWidget);

    await tester.ensureVisible(find.text('Последний герой'));
    await tester.pump();
    await tester.tap(find.text('Последний герой'));
    await tester.pump();

    await tester.ensureVisible(find.byTooltip('Выбрать треки').first);
    await tester.pump();
    await tester.tap(find.byTooltip('Выбрать треки').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Война'));
    await tester.pump();
    await tester.tap(find.text('Война'));
    await tester.pump();

    expect(c.drafts.value.single.trackCount, 10 + 10 + 1);
    expect(find.text('Выбрано 3 релиза · 21 трек'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Скачать'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    final select = core.lastDownload!['select'] as List;
    expect(select, hasLength(3));
    expect((select[0] as Map)['album'], '10');
    expect((select[0] as Map)['tracks'], hasLength(10));
    expect((select[0] as Map)['tracks'], isNot(contains('103')));
    expect((select[1] as Map).containsKey('tracks'), isFalse);
    expect(select.map((s) => (s as Map)['album']), isNot(contains('13')));
    expect(c.jobs.first.tracks, hasLength(21));

    await tester.pumpAndSettle(const Duration(seconds: 5));
    await core.close();
  });

  testWidgets('у альбома можно выбрать треки, 18+ помечено', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'good-token');

    await _add(tester, 'https://music.yandex.ru/album/123');
    expect(find.text('E'), findsOneWidget);
    expect(find.text('Все треки · 8 треков'), findsOneWidget);

    await tester.tap(find.text('Выбрать треки'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('E'), findsNWidgets(1 + 4));

    await tester.ensureVisible(find.text('Война'));
    await tester.pump();
    await tester.tap(find.text('Война'));
    await tester.pump();
    await tester.ensureVisible(find.text('Кукушка'));
    await tester.pump();
    await tester.tap(find.text('Кукушка'));
    await tester.pump();
    expect(find.text('Выбрано 6 из 8 треков'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Скачать'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    final select = core.lastDownload!['select'] as List;
    expect(select, hasLength(1));
    expect((select.single as Map)['album'], '123');
    expect((select.single as Map)['tracks'], hasLength(6));
    expect((select.single as Map)['tracks'], isNot(contains('1233')));
    expect(c.jobs.first.tracks, hasLength(6));

    await tester.pumpAndSettle(const Duration(seconds: 5));
    await core.close();
  });
}
