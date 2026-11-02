import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/controller.dart';
import '../state/draft.dart';
import '../state/models.dart';
import '../state/picker.dart';
import '../theme.dart';
import 'artist_picker.dart';
import 'widgets.dart';

class LinkPanel extends StatefulWidget {
  const LinkPanel({super.key, required this.c});

  final Controller c;

  @override
  State<LinkPanel> createState() => _LinkPanelState();
}

class _LinkPanelState extends State<LinkPanel> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  Controller get c => widget.c;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pasteInline() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = (data?.text ?? '').trim();
    if (text.isEmpty) return;
    if (text.contains('\n') || splitLinks(text).length > 1) {
      c.addLinks(text);
      return;
    }
    final v = _input.value;
    final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    _input.value = TextEditingValue(
      text: v.text.replaceRange(sel.start, sel.end, text),
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
  }

  void _submit() {
    final text = _input.text;
    if (text.trim().isEmpty) {
      _input.clear();
      return;
    }
    c.addLinks(text);
    _input.clear();
    _focus.requestFocus();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isNotEmpty) c.addLinks(text);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: ValueListenableBuilder(
        valueListenable: c.drafts,
        builder: (context, drafts, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  Text('Подборка', style: text.titleMedium),
                  if (drafts.isNotEmpty) ...[const SizedBox(width: 8), Tag('${drafts.length}')],
                  const Spacer(),
                  if (drafts.isNotEmpty)
                    TextButton.icon(
                      onPressed: c.clearDrafts,
                      icon: const Icon(Icons.clear_all_rounded, size: 18),
                      label: const Text('Очистить'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: _input,
              builder: (context, _) => Actions(
                actions: {
                  PasteTextIntent: CallbackAction<PasteTextIntent>(
                    onInvoke: (_) {
                      _pasteInline();
                      return null;
                    },
                  ),
                },
                child: TextField(
                  controller: _input,
                  focusNode: _focus,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Ссылки с music.yandex.ru',
                    prefixIcon: const Icon(Icons.link_rounded),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _input.text.trim().isEmpty
                          ? IconButton(
                              tooltip: 'Вставить',
                              icon: const Icon(Icons.content_paste_rounded),
                              onPressed: _paste,
                            )
                          : IconButton.filled(
                              tooltip: 'Добавить',
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                shape: const CircleBorder(),
                                fixedSize: const Size(34, 34),
                                minimumSize: const Size(34, 34),
                                padding: EdgeInsets.zero,
                              ),
                              iconSize: 20,
                              icon: const Icon(Icons.add_rounded),
                              onPressed: _submit,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: drafts.isEmpty
                  ? const _Hint()
                  : ListView.separated(
                      itemCount: drafts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => DraftCard(key: ObjectKey(drafts[i]), draft: drafts[i], c: c),
                    ),
            ),
            if (drafts.isNotEmpty) _Footer(c: c, drafts: drafts),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вставьте одну ссылку или сразу пачку: треки, альбомы, плейлисты, исполнители. '
              'Каждая станет карточкой с названием и обложкой, а скачать можно всё разом.',
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Tag('Трек', icon: Icons.music_note_rounded),
                Tag('Альбом', icon: Icons.album_rounded),
                Tag('Плейлист', icon: Icons.queue_music_rounded),
                Tag('Исполнитель', icon: Icons.person_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.c, required this.drafts});

  final Controller c;
  final List<Draft> drafts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge(drafts),
      builder: (context, _) {
        final ready = drafts.where((d) => d.ready).toList();
        final tracks = ready.fold(0, (n, d) => n + d.trackCount);
        final loading = drafts.where((d) => d.loading).length;
        final parts = [
          if (ready.isNotEmpty) '${ready.length} ${_links(ready.length)} · ${tracksLabel(tracks)}',
          if (loading > 0) 'загружается $loading',
        ];
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      parts.isEmpty ? 'Нечего скачивать' : parts.join(' · '),
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                  Tag(
                    c.quality == Quality.lossless ? 'FLAC' : 'MP3 320',
                    icon: Icons.graphic_eq_rounded,
                    color: context.status.accent,
                  ),
                ],
              ),
              const SizedBox(height: 10),
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

  static String _links(int n) {
    final mod10 = n % 10, mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'ссылка';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'ссылки';
    return 'ссылок';
  }
}

class DraftCard extends StatelessWidget {
  const DraftCard({super.key, required this.draft, required this.c});

  final Draft draft;
  final Controller c;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final p = draft.preview;
        final picker = draft.picker;
        final isAlbum = p.kind == ReleaseKind.album;
        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: draft.failed ? Border.all(color: scheme.error.withValues(alpha: 0.4)) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
                child: Row(
                  children: [
                    _leading(context),
                    const SizedBox(width: 12),
                    Expanded(child: _info(context, text, scheme)),
                    if (p.status == PreviewStatus.ok)
                      IconButton(
                        tooltip: 'Скачать',
                        icon: const Icon(Icons.download_rounded),
                        onPressed: draft.ready ? () => c.downloadDraft(draft) : null,
                      ),
                    IconButton(
                      tooltip: 'Убрать',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => c.removeDraft(draft),
                    ),
                  ],
                ),
              ),
              if (picker != null) ...[
                Divider(height: 1, indent: 12, endIndent: 12, color: scheme.outlineVariant),
                InkWell(
                  onTap: draft.togglePicker,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                    child: Row(
                      children: [
                        Icon(Icons.checklist_rounded, size: 18, color: context.status.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _summary(picker, isAlbum),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: picker.nothing ? scheme.error : scheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          draft.pickerOpen ? 'Свернуть' : (isAlbum ? 'Выбрать треки' : 'Выбрать релизы'),
                          style: TextStyle(fontSize: 12.5, color: context.status.accent),
                        ),
                        AnimatedRotation(
                          turns: draft.pickerOpen ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.expand_more_rounded, color: context.status.accent),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: draft.pickerOpen
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 8, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => picker.selectAll(!picker.everything),
                                  child: Text(picker.everything ? 'Снять всё' : 'Выбрать всё'),
                                ),
                              ),
                              isAlbum
                                  ? TrackChecklist(picker: picker, albumId: picker.albums.first.id, indent: 0)
                                  : AlbumList(picker: picker),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _summary(ArtistPicker picker, bool isAlbum) {
    if (picker.nothing) return 'Ничего не выбрано';
    if (isAlbum) {
      final total = picker.albums.first.count;
      return picker.everything
          ? 'Все треки · ${tracksLabel(total)}'
          : 'Выбрано ${picker.trackCount} из ${tracksLabel(total)}';
    }
    return picker.everything
        ? 'Вся дискография · ${tracksLabel(picker.trackCount)}'
        : 'Выбрано ${releasesLabel(picker.albumCount)} · ${tracksLabel(picker.trackCount)}';
  }

  Widget _leading(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = draft.preview;
    if (p.status == PreviewStatus.ok) return Cover(url: p.cover, size: 52, kind: p.kind);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: draft.failed
            ? Icon(Icons.link_off_rounded, color: scheme.error)
            : const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2)),
      ),
    );
  }

  Widget _info(BuildContext context, TextTheme text, ColorScheme scheme) {
    final p = draft.preview;
    if (p.status != PreviewStatus.ok) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(draft.link, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
          const SizedBox(height: 2),
          Text(
            draft.failed
                ? (p.message.isEmpty ? 'Не удалось открыть ссылку' : p.message)
                : 'Узнаю, что по ссылке…',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: draft.failed ? scheme.error : scheme.onSurfaceVariant),
          ),
        ],
      );
    }
    final overline = [p.kind.label.toUpperCase(), if (p.year > 0) '${p.year}'].join('  ·  ');
    final sub = [
      if (p.artist.isNotEmpty && p.kind != ReleaseKind.artist) p.artist,
      if (p.kind == ReleaseKind.artist && draft.picker != null)
        releasesLabel(draft.picker!.albums.length)
      else if (p.count > 0)
        tracksLabel(p.count),
    ].join(' · ');
    return Tooltip(
      message: p.folder,
      waitDuration: const Duration(milliseconds: 700),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overline,
            style: text.labelSmall?.copyWith(
              color: context.status.accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          TitleWithBadge(p.title, explicit: p.explicit, style: text.titleMedium),
          if (sub.isNotEmpty)
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
