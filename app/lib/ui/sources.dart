import 'package:flutter/material.dart';

import '../state/controller.dart';
import '../state/draft.dart';
import '../state/models.dart';
import '../theme.dart';
import 'artist_picker.dart';
import 'widgets.dart';

String draftSummary(Draft d) {
  final p = d.preview;
  if (d.loading) return 'Узнаю, что по ссылке…';
  if (d.failed) return p.message.isEmpty ? 'Не удалось открыть ссылку' : p.message;
  final pk = d.picker;
  if (p.kind == ReleaseKind.artist && pk != null) {
    if (pk.nothing) return 'ничего не выбрано';
    if (pk.everything) return 'вся дискография · ${tracksLabel(pk.trackCount)}';
    return '${pk.albumCount} из ${ofReleases(pk.albums.length)} · ${tracksLabel(pk.trackCount)}';
  }
  if (p.kind != ReleaseKind.artist && pk != null) {
    final total = pk.albums.first.count;
    final picked = pk.nothing
        ? 'ничего не выбрано'
        : pk.everything
            ? tracksLabel(total)
            : '${pk.trackCount} из ${ofTracks(total)}';
    return [if (p.artist.isNotEmpty) p.artist, picked].join(' · ');
  }
  return [
    if (p.artist.isNotEmpty) p.artist,
    if (p.kind != ReleaseKind.track && p.count > 0) tracksLabel(p.count),
  ].join(' · ');
}

class SourceList extends StatelessWidget {
  const SourceList({super.key, required this.c, this.onOpen});

  final Controller c;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([c.drafts, c.selected]),
      builder: (context, _) {
        final drafts = c.drafts.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Подборка',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '  ·  ${drafts.length}',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: c.clearDrafts, child: const Text('Очистить')),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                itemCount: drafts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (_, i) => SourceRow(
                  key: ObjectKey(drafts[i]),
                  draft: drafts[i],
                  selected: drafts[i] == c.selected.value,
                  c: c,
                  onOpen: onOpen,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SourceRow extends StatelessWidget {
  const SourceRow({super.key, required this.draft, required this.selected, required this.c, this.onOpen});

  final Draft draft;
  final bool selected;
  final Controller c;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final p = draft.preview;
        final over = draft.failed
            ? 'ОШИБКА'
            : draft.loading
                ? 'ЗАГРУЗКА'
                : [p.kind.label.toUpperCase(), if (p.year > 0) '${p.year}'].join(' · ');
        final title = p.status == PreviewStatus.ok ? p.title : draft.link;
        return Material(
          color: selected ? scheme.surfaceContainerHigh : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? context.status.accent.withValues(alpha: 0.7) : Colors.transparent,
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              c.selected.value = draft;
              onOpen?.call();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
              child: Row(
                children: [
                  _leading(context),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          over,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: draft.failed ? scheme.error : context.status.accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        TitleWithBadge(
                          title,
                          explicit: p.explicit,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          draftSummary(draft),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: draft.failed ? scheme.error : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Убрать',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, size: 18, color: scheme.onSurfaceVariant),
                    onPressed: () => c.removeDraft(draft),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _leading(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = draft.preview;
    if (p.status == PreviewStatus.ok) return Cover(url: p.cover, size: 48, kind: p.kind, radius: 10);
    return Container(
      width: 48,
      height: 48,
      decoration:
          BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Center(
        child: draft.failed
            ? Icon(Icons.link_off_rounded, color: scheme.error, size: 22)
            : const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
      ),
    );
  }
}
