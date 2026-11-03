import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ymd/app.dart';
import 'package:ymd/core/fake_core.dart';
import 'package:ymd/state/controller.dart';
import 'package:ymd/state/models.dart';
import 'package:ymd/state/search.dart';

Future<(FakeCore, Controller)> _open(
  WidgetTester tester, {
  String latest = '2.1.1',
  Duration tick = const Duration(milliseconds: 120),
}) async {
  tester.view.physicalSize = const Size(1280, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final core = FakeCore(latest: latest, tick: tick);
  final controller = Controller(core);
  await tester.pumpWidget(YmdApp(controller: controller));
  await tester.pumpAndSettle();
  return (core, controller);
}

Future<void> _login(WidgetTester tester, String token) async {
  await tester.enterText(find.byType(TextField), token);
  await tester.pump();
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

Future<void> _downloadAll(WidgetTester tester) async {
  await tester.tap(find.byWidgetPredicate((w) => w is FilledButton).last);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  testWidgets('без входа виден только экран входа', (tester) async {
    final (core, c) = await _open(tester);

    expect(c.ready, isTrue);
    expect(c.version, '2.1.1');
    expect(find.text('Войти'), findsOneWidget);
    expect(find.text('Что скачаем?'), findsNothing);

    await core.close();
  });

  testWidgets('без Плюса скачивание недоступно', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'noplus');

    expect(c.account.status, AccountStatus.noplus);
    expect(c.canDownload, isFalse);
    expect(find.text('Оформить Плюс'), findsOneWidget);
    expect(find.text('Что скачаем?'), findsNothing);

    await core.close();
  });

  testWidgets('неверный токен показывает ошибку', (tester) async {
    final (core, _) = await _open(tester);
    await _login(tester, 'bad');

    expect(find.textContaining('недействителен'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);

    await core.close();
  });

  testWidgets('альбом определяется по ссылке и качается, загрузки открываются сами', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'good-token');

    expect(c.canDownload, isTrue);
    expect(find.text('Что скачаем?'), findsOneWidget);
    expect(find.text('Плюс'), findsOneWidget);

    await _add(tester, 'https://music.yandex.ru/album/123');

    expect(find.text('Что скачаем?'), findsNothing);
    expect(find.text('Группа крови'), findsWidgets);
    expect(find.text('Кино · 8 треков'), findsOneWidget);
    expect(find.text('1 ссылка · 8 треков'), findsOneWidget);

    await _downloadAll(tester);
    expect(c.drafts.value, isEmpty);
    expect(c.downloadsOpen.value, isTrue);
    expect(find.text('Загрузки'), findsOneWidget);
    expect(c.jobs, hasLength(1));
    expect(c.jobs.first.tracks, hasLength(8));

    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump();
    expect(c.jobs.first.count(TrackStatus.active), 4);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(c.jobs.first.status, JobStatus.done);
    expect(c.jobs.first.formats, containsAll(['FLAC 24/96', 'FLAC 16/44.1']));

    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(c.downloadsOpen.value, isFalse);

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
    expect(c.selected.value, c.drafts.value.first);
    expect(find.text('Кукушка'), findsWidgets);
    expect(find.text('Плейлист дня'), findsOneWidget);
    expect(find.text('Не удалось распознать ссылку.'), findsOneWidget);
    expect(find.text('3 ссылки · 15 треков'), findsOneWidget);

    await tester.tap(find.text('Плейлист дня'));
    await tester.pumpAndSettle();
    expect(find.text('6 треков · выбрано 6'), findsOneWidget);
    expect(find.text('Аквариум'), findsWidgets);

    await tester.tap(find.text('Война'));
    await tester.pump();
    expect(find.text('6 треков · выбрано 5'), findsOneWidget);

    await _add(tester, 'https://music.yandex.ru/album/123');
    expect(c.drafts.value, hasLength(4));
    expect(c.selected.value, c.drafts.value.first);
    expect(find.text('Уже в подборке, открыл её'), findsOneWidget);

    await _downloadAll(tester);
    expect(c.jobs, hasLength(3));
    expect(c.drafts.value, hasLength(1));
    final select = core.lastDownload?['select'] as List?;
    expect((select?.single as Map)['tracks'], hasLength(5));

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
    expect(find.text('Что скачаем?'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(c.canDownload, isTrue);
    expect(find.text('Что скачаем?'), findsOneWidget);
    expect(find.text('Подписка Плюс активна'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 5));
    await core.close();
  });

  testWidgets('у исполнителя выбираются релизы и треки', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'good-token');

    await _add(tester, 'https://music.yandex.ru/artist/1');
    expect(find.text('вся дискография · 33 трека'), findsOneWidget);
    expect(find.text('Альбомы · 2'), findsOneWidget);
    expect(find.text('Синглы и EP · 1'), findsOneWidget);
    expect(find.text('Сборники · 1'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).at(3));
    await tester.pump();
    expect(find.text('не выбран'), findsOneWidget);

    await tester.tap(find.text('все треки').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Война'));
    await tester.pump();
    await tester.tap(find.byTooltip('Готово'));
    await tester.pumpAndSettle();

    expect(find.text('10 из 11'), findsOneWidget);
    expect(find.text('3 из 4 релизов · 21 трек'), findsOneWidget);

    await tester.tap(find.text('Сборники · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Последний герой'), findsOneWidget);
    expect(find.text('Группа крови'), findsNothing);

    await _downloadAll(tester);
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

  testWidgets('в альбоме выбираются треки, 18+ помечено', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'good-token');

    await _add(tester, 'https://music.yandex.ru/album/123');
    expect(find.text('E'), findsNWidgets(2 + 4));

    await tester.tap(find.text('Война'));
    await tester.pump();
    await tester.tap(find.text('Кукушка'));
    await tester.pump();
    expect(find.text('Кино · 6 из 8 треков'), findsOneWidget);

    await _downloadAll(tester);
    final select = core.lastDownload!['select'] as List;
    expect(select, hasLength(1));
    expect((select.single as Map)['album'], '123');
    expect((select.single as Map)['tracks'], hasLength(6));
    expect((select.single as Map)['tracks'], isNot(contains('1233')));
    expect(c.jobs.first.tracks, hasLength(6));

    await tester.pumpAndSettle(const Duration(seconds: 5));
    await core.close();
  });

  testWidgets('в настройках можно проверить обновления', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'good-token');

    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    expect(find.text('Версия 2.1.1'), findsOneWidget);

    await tester.tap(find.text('Проверить'));
    await tester.pump();
    expect(find.text('Проверяю обновления…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(c.update?.available, isFalse);
    expect(find.text('Это последняя версия'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 5));
    await core.close();
  });

  testWidgets('новая версия предлагается при запуске', (tester) async {
    final (core, c) = await _open(tester, latest: '2.2.0');

    expect(find.text('Доступна версия 2.2.0'), findsNothing);
    await _login(tester, 'good-token');
    expect(find.text('Доступна версия 2.2.0'), findsOneWidget);
    expect(find.text('Самообновление из релизов GitHub.'), findsOneWidget);

    await tester.tap(find.text('Обновить'));
    await tester.pump();
    expect(c.updating, isTrue);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(c.updateProgress.value, 1.0);

    await tester.pumpAndSettle(const Duration(seconds: 5));
    await core.close();
  });

  testWidgets('очистку подборки можно отменить', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'good-token');
    await _add(tester, 'https://music.yandex.ru/album/123 https://music.yandex.ru/album/1/track/5');
    expect(c.drafts.value, hasLength(2));

    await tester.tap(find.text('Очистить'));
    await tester.pumpAndSettle();
    expect(c.drafts.value, isEmpty);
    expect(find.text('Подборка очищена'), findsOneWidget);

    await tester.tap(find.text('Вернуть'));
    await tester.pumpAndSettle();
    expect(c.drafts.value, hasLength(2));
    expect(find.text('Группа крови'), findsWidgets);

    await tester.pumpAndSettle(const Duration(seconds: 5));
    await core.close();
  });

  testWidgets('карточку можно скачать отдельно, Esc закрывает загрузки', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'good-token');
    await _add(tester, 'https://music.yandex.ru/album/123 https://music.yandex.ru/album/1/track/5');

    await tester.tap(find.text('Скачать альбом'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(c.jobs, hasLength(1));
    expect(c.drafts.value, hasLength(1));
    expect(c.downloadsOpen.value, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(c.downloadsOpen.value, isFalse);

    await tester.pumpAndSettle(const Duration(seconds: 10));
    await core.close();
  });

  testWidgets('выход во время загрузки нужно подтвердить', (tester) async {
    final (core, c) = await _open(tester, tick: const Duration(seconds: 30));
    await _login(tester, 'good-token');
    await _add(tester, 'https://music.yandex.ru/album/123');
    await _downloadAll(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    Future<void> logout() async {
      await tester.tap(find.text('Иван Петров'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Выйти'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.running, 1);
      expect(find.text('Выйти из аккаунта?'), findsOneWidget);
    }

    await logout();
    await tester.tap(find.text('Отмена'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.canDownload, isTrue);

    await logout();
    await tester.tap(find.widgetWithText(FilledButton, 'Выйти'));
    await tester.pumpAndSettle();
    expect(c.canDownload, isFalse);
    expect(find.text('Войти'), findsOneWidget);

    await core.close();
  });
  testWidgets('поиск по названию: живые результаты, добавление в подборку и скачивание', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'good-token');

    await tester.enterText(find.byType(TextField), 'кино');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(c.search.open, isTrue);
    expect(find.text('Что скачаем?'), findsNothing);
    expect(find.text('Лучший результат'), findsOneWidget);
    expect(find.byTooltip('Закрыть поиск'), findsOneWidget);
    expect(find.text('Война'), findsOneWidget);
    expect(find.text('Звезда по имени Солнце'), findsWidgets);

    await tester.tap(find.text('Добавить в подборку'));
    await tester.pumpAndSettle();
    expect(c.drafts.value.map((d) => d.link), ['https://music.yandex.ru/artist/1']);
    expect(find.text('Убрать из подборки'), findsOneWidget);

    await tester.tap(find.text('Война'));
    await tester.pumpAndSettle();
    expect(c.drafts.value, hasLength(2));
    expect(find.textContaining('2 ссылки · '), findsOneWidget);

    await tester.tap(find.text('Война'));
    await tester.pumpAndSettle();
    expect(c.drafts.value, hasLength(1));
    expect(find.text('Убрано из подборки'), findsOneWidget);

    await tester.tap(find.byTooltip('Закрыть поиск'));
    await tester.pumpAndSettle();
    expect(c.search.open, isFalse);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.text('Подборка'), findsOneWidget);

    await _downloadAll(tester);
    expect(c.jobs, hasLength(1));
    expect(core.lastDownload?['link'], 'https://music.yandex.ru/artist/1');

    await tester.pumpAndSettle(const Duration(seconds: 10));
    await core.close();
  });

  testWidgets('поиск: раздел целиком, догрузка и исправление опечатки', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'good-token');

    await tester.enterText(find.byType(TextField), 'кина');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('«кино»'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Треки'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(c.search.filter, ReleaseKind.track);
    expect(c.search.results?[ReleaseKind.track]?.hits, hasLength(10));

    await tester.scrollUntilVisible(find.text('Показать ещё'), 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Показать ещё'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(c.search.results?[ReleaseKind.track]?.hits, hasLength(20));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Всё'));
    await tester.pumpAndSettle();
    expect(find.text('Лучший результат'), findsOneWidget);

    await tester.tap(find.text('«кино»'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(c.search.query, 'кино');
    expect(find.text('«кино»'), findsNothing);

    Focus.of(tester.element(find.descendant(of: find.byType(ChoiceChip), matching: find.text('Треки')))).requestFocus();
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(c.search.open, isFalse);
    expect(find.text('Что скачаем?'), findsOneWidget);

    await core.close();
  });

  testWidgets('поиск: пусто, ошибка и ссылка в том же поле', (tester) async {
    final (core, c) = await _open(tester);
    await _login(tester, 'good-token');

    Future<void> query(String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
    }

    await query('пусто');
    expect(find.text('Ничего не нашлось'), findsOneWidget);

    await query('ошибка');
    expect(find.text('Поиск не удался'), findsOneWidget);
    expect(c.search.results?.status, SearchStatus.error);

    await _add(tester, 'https://music.yandex.ru/album/123');
    expect(c.search.open, isFalse);
    expect(c.drafts.value, hasLength(1));
    expect(find.text('Кино · 8 треков'), findsOneWidget);

    await core.close();
  });
}
