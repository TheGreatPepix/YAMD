import 'package:flutter/material.dart';

import '../state/controller.dart';
import '../state/draft.dart';
import '../state/models.dart';
import '../state/picker.dart';
import '../theme.dart';
import 'artist_picker.dart';
import 'widgets.dart';

class SourceDetail extends StatelessWidget {
  const SourceDetail({super.key, required this.c});

  final Controller c;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: c.selected,
      builder: (context, draft, _) {
        if (draft == null) return const SizedBox.shrink();
        return ListenableBuilder(
          key: ObjectKey(draft),
          listenable: draft,
          builder: (context, _) {
            final p = draft.preview;
            final pk = draft.picker;
            if (draft.loading) return const _Loading();
            if (draft.failed) return _Failed(draft: draft, c: c);
            if (p.kind == ReleaseKind.artist && pk != null) return _ArtistView(preview: p, picker: pk);
            if (p.kind == ReleaseKind.album && pk != null) return _AlbumView(preview: p, picker: pk);
            return _SimpleView(preview: p);
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.cover,
    required this.over,
    required this.title,
    required this.explicit,
    required this.lines,
    this.action,
    this.end = 0,
  });

  final Widget cover;
  final String over, title;
  final bool explicit;
  final List<String> lines;
  final Widget? action;
  final double end;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        cover,
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                over,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: context.status.accent,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.15),
                    ),
                  ),
                  if (explicit) ...[const SizedBox(width: 10), const ExplicitBadge(size: 18)],
                ],
              ),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(l, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                ),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
    return Padding(padding: EdgeInsets.only(right: end), child: row);
  }
}

class _ArtistView extends StatefulWidget {
  const _ArtistView({required this.preview, required this.picker});

  final Preview preview;
  final ArtistPicker picker;

  @override
  State<_ArtistView> createState() => _ArtistViewState();
}

class _ArtistViewState extends State<_ArtistView> {
  AlbumType? _filter;

  @override
  Widget build(BuildContext context) {
    final p = widget.preview;
    final pk = widget.picker;
    final shown = _filter == null ? pk.albums : pk.ofType(_filter!).toList();
    final scheme = Theme.of(context).colorScheme;
    Widget chip(String label, AlbumType? type) {
      final on = _filter == type;
      return ChoiceChip(
        label: Text(label),
        selected: on,
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = type),
        selectedColor: scheme.onSurface,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, color: on ? scheme.surface : scheme.onSurface),
        shape: StadiumBorder(side: BorderSide(color: on ? scheme.onSurface : scheme.outlineVariant)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            end: 28,
            cover: Cover(url: p.cover, size: 84, kind: ReleaseKind.artist),
            over: 'ИСПОЛНИТЕЛЬ',
            title: p.title,
            explicit: false,
            lines: [
              '${releasesLabel(pk.albums.length)} · выбрано ${pk.albumCount} · ${tracksLabel(pk.trackCount)}',
            ],
            action: OutlinedButton(
              onPressed: () => pk.selectAll(!pk.everything),
              child: Text(pk.everything ? 'Снять всё' : 'Выбрать всё'),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip('Все · ${pk.albums.length}', null),
              for (final t in pk.types) chip('${t.label} · ${pk.ofType(t).length}', t),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(right: 28, bottom: 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 22,
                crossAxisSpacing: 20,
                childAspectRatio: 0.74,
              ),
              itemCount: shown.length,
              itemBuilder: (_, i) => _ReleaseTile(picker: pk, album: shown[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseTile extends StatelessWidget {
  const _ReleaseTile({required this.picker, required this.album});

  final ArtistPicker picker;
  final AlbumOption album;

  String get _kind => switch (album.type) {
        AlbumType.album => 'Альбом',
        AlbumType.single => 'Сингл',
        AlbumType.compilation => 'Сборник',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = picker.albumState(album.id);
    final picked = picker.pickedCount(album.id);
    final pickLabel = state == true
        ? 'все треки'
        : state == null
            ? '$picked из ${album.count}'
            : 'не выбран';
    final meta = [_kind, if (album.year > 0) '${album.year}', if (album.count > 0) tracksLabel(album.count)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              children: [
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: state == false ? 0.45 : 1,
                    child: Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => picker.toggleAlbum(album.id),
                        child:
                            Cover(url: album.cover, size: box.maxWidth, kind: ReleaseKind.album, radius: 14),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Checkbox(
                      tristate: true,
                      value: state,
                      onChanged: (_) => picker.toggleAlbum(album.id),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => showTracksDialog(context, picker, album),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pickLabel,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        TitleWithBadge(album.title,
            explicit: album.explicit, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          meta.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

Future<void> showTracksDialog(BuildContext context, ArtistPicker picker, AlbumOption album) {
  if (!picker.isExpanded(album.id)) picker.toggleExpanded(album.id);
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: ListenableBuilder(
          listenable: picker,
          builder: (context, _) {
            final state = picker.albumState(album.id);
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Cover(url: album.cover, size: 48, kind: ReleaseKind.album, radius: 10),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TitleWithBadge(
                          album.title,
                          explicit: album.explicit,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => picker.setAlbum(album.id, state != true),
                        child: Text(state == true ? 'Снять всё' : 'Выбрать всё'),
                      ),
                      IconButton(
                        tooltip: 'Готово',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      child: TrackChecklist(picker: picker, albumId: album.id, indent: 0),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _AlbumView extends StatelessWidget {
  const _AlbumView({required this.preview, required this.picker});

  final Preview preview;
  final ArtistPicker picker;

  @override
  Widget build(BuildContext context) {
    final p = preview;
    final album = picker.albums.first;
    final state = picker.albumState(album.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            end: 28,
            cover: Cover(url: p.cover, size: 150, kind: ReleaseKind.album, radius: 16),
            over: ['АЛЬБОМ', if (p.year > 0) '${p.year}'].join(' · '),
            title: p.title,
            explicit: p.explicit,
            lines: [
              if (p.artist.isNotEmpty) p.artist,
              '${tracksLabel(album.count)} · выбрано ${picker.pickedCount(album.id)}',
            ],
            action: OutlinedButton(
              onPressed: () => picker.setAlbum(album.id, state != true),
              child: Text(state == true ? 'Снять всё' : 'Выбрать всё'),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 28, bottom: 24),
              child: TrackChecklist(picker: picker, albumId: album.id, indent: 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleView extends StatelessWidget {
  const _SimpleView({required this.preview});

  final Preview preview;

  @override
  Widget build(BuildContext context) {
    final p = preview;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            cover: Cover(url: p.cover, size: 150, kind: p.kind, radius: 16),
            over: [p.kind.label.toUpperCase(), if (p.year > 0) '${p.year}'].join(' · '),
            title: p.title,
            explicit: p.explicit,
            lines: [
              if (p.artist.isNotEmpty) p.artist,
              if (p.kind != ReleaseKind.track && p.count > 0) tracksLabel(p.count),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                p.kind == ReleaseKind.playlist ? 'Плейлист скачается целиком' : 'Трек скачается как есть',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
        child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.6)));
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.draft, required this.c});

  final Draft draft;
  final Controller c;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = draft.preview.message;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off_rounded, size: 44, color: scheme.error),
            const SizedBox(height: 14),
            Text(draft.link, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message.isEmpty ? 'Не удалось открыть ссылку' : message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            OutlinedButton(onPressed: () => c.removeDraft(draft), child: const Text('Убрать из подборки')),
          ],
        ),
      ),
    );
  }
}
