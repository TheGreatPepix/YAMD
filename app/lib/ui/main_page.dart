import 'package:flutter/material.dart';

import '../state/controller.dart';
import '../state/draft.dart';
import '../state/models.dart';
import '../theme.dart';
import 'downloads.dart';
import 'link_input.dart';
import 'log_dialog.dart';
import 'settings_dialog.dart';
import 'source_detail.dart';
import 'sources.dart';
import 'widgets.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key, required this.c});

  final Controller c;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([c.drafts, c.downloadsOpen]),
          builder: (context, _) {
            final empty = c.drafts.value.isEmpty;
            final open = c.downloadsOpen.value;
            return Stack(
              children: [
                Column(
                  children: [
                    _Header(c: c, withInput: !empty),
                    Divider(height: 1, color: scheme.outlineVariant),
                    Expanded(
                      child: empty
                          ? _Hero(c: c)
                          : LayoutBuilder(
                              builder: (context, box) => Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(width: box.maxWidth >= 1100 ? 340 : 280, child: SourceList(c: c)),
                                  VerticalDivider(width: 1, color: scheme.outlineVariant),
                                  Expanded(child: SourceDetail(c: c)),
                                ],
                              ),
                            ),
                    ),
                    if (!empty) _ActionBar(c: c),
                  ],
                ),
                if (open) ...[
                  Positioned.fill(
                    top: 73,
                    child: GestureDetector(
                      onTap: () => c.downloadsOpen.value = false,
                      child: ColoredBox(color: Colors.black.withValues(alpha: 0.5)),
                    ),
                  ),
                  Positioned(
                    top: 80,
                    right: 12,
                    bottom: 12,
                    width: 440,
                    child: DownloadsPanel(c: c),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.c, required this.withInput});

  final Controller c;
  final bool withInput;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const BrandMark(size: 34),
            const SizedBox(width: 10),
            Text('YAMD',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: 24),
            Expanded(
              child: withInput
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: LinkInput(c: c),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 24),
            DownloadsButton(c: c),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Журнал',
              icon: const Icon(Icons.receipt_long_rounded),
              onPressed: () => showLogDialog(context, c),
            ),
            IconButton(
              tooltip: 'Настройки',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => showSettingsDialog(context, c),
            ),
            const SizedBox(width: 6),
            _AccountPill(c: c),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.c});

  final Controller c;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget point(String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: context.status.accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          ],
        );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Что скачаем?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1.2),
            ),
            const SizedBox(height: 12),
            Text(
              'Вставьте одну ссылку или сразу пачку. Название, исполнитель и обложка '
              'определятся сами, а нужное можно отметить галочками.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 26),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: LinkInput(c: c, hero: true),
            ),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                Tag('Трек', icon: Icons.music_note_rounded),
                Tag('Альбом', icon: Icons.album_rounded),
                Tag('Плейлист', icon: Icons.queue_music_rounded),
                Tag('Исполнитель', icon: Icons.person_rounded),
              ],
            ),
            const SizedBox(height: 36),
            Wrap(
              spacing: 32,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                point(c.quality == Quality.lossless ? 'FLAC до 24 бит / 192 кГц' : 'MP3 320'),
                point('До ${c.concurrency} треков одновременно'),
                point('Теги и обложки сами'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.c});

  final Controller c;

  static String _sources(int n) {
    final mod10 = n % 10, mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return '$n источник';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return '$n источника';
    return '$n источников';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final drafts = c.drafts.value;
    return ListenableBuilder(
      listenable: Listenable.merge([c, ...drafts]),
      builder: (context, _) {
        final ready = drafts.where((Draft d) => d.ready).toList();
        final tracks = ready.fold(0, (n, d) => n + d.trackCount);
        final loading = drafts.where((d) => d.loading).length;
        final summary = [
          if (ready.isNotEmpty) '${_sources(ready.length)} · ${tracksLabel(tracks)}' else 'Нечего скачивать',
          if (loading > 0) 'загружается $loading',
        ].join(' · ');
        return Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Text(summary, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(width: 14),
              Tag(
                c.quality == Quality.lossless ? 'FLAC' : 'MP3 320',
                icon: Icons.graphic_eq_rounded,
                color: context.status.accent,
              ),
              const SizedBox(width: 14),
              Icon(Icons.folder_rounded, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Tooltip(
                  message: c.dir,
                  child: Text(
                    c.dir,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: ready.isEmpty ? null : c.downloadAll,
                icon: const Icon(Icons.download_rounded),
                label: Text(ready.length > 1 ? 'Скачать всё' : 'Скачать'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountPill extends StatelessWidget {
  const _AccountPill({required this.c});

  final Controller c;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const shape = StadiumBorder();
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            c.account.login.isNotEmpty ? c.account.login : c.account.displayName,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.verified_outlined),
          onPressed: c.recheck,
          child: const Text('Проверить подписку'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.logout_rounded),
          onPressed: c.logout,
          child: const Text('Выйти'),
        ),
      ],
      builder: (context, menu, _) => Tooltip(
        message: 'Аккаунт',
        child: Material(
          color: scheme.surfaceContainerHigh,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: shape,
            onTap: () => menu.isOpen ? menu.close() : menu.open(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AccountAvatar(account: c.account, size: 30),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      c.account.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const PlusBadge(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
