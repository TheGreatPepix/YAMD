import 'package:flutter/material.dart';

import '../state/models.dart';
import '../state/picker.dart';
import 'widgets.dart';

String releasesLabel(int n) {
  final mod10 = n % 10, mod100 = n % 100;
  final word = (mod10 == 1 && mod100 != 11)
      ? 'релиз'
      : (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
          ? 'релиза'
          : 'релизов';
  return '$n $word';
}

class AlbumList extends StatelessWidget {
  const AlbumList({super.key, required this.picker});

  final ArtistPicker picker;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final type in picker.types) ...[
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => picker.toggleType(type),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Checkbox(
                    tristate: true,
                    value: picker.typeState(type),
                    onChanged: (_) => picker.toggleType(type),
                  ),
                  Text(
                    type.label,
                    style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
                  ),
                  const SizedBox(width: 8),
                  Tag('${picker.ofType(type).length}'),
                ],
              ),
            ),
          ),
          for (final a in picker.ofType(type)) _AlbumTile(picker: picker, album: a),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.picker, required this.album});

  final ArtistPicker picker;
  final AlbumOption album;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expanded = picker.isExpanded(album.id);
    final meta =
        [if (album.year > 0) '${album.year}', if (album.count > 0) tracksLabel(album.count)].join(' · ');
    final error = picker.error(album.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => picker.toggleAlbum(album.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  tristate: true,
                  value: picker.albumState(album.id),
                  onChanged: (_) => picker.toggleAlbum(album.id),
                ),
                Cover(url: album.cover, size: 40, kind: ReleaseKind.album, radius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TitleWithBadge(
                        album.title,
                        explicit: album.explicit,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        error ?? meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: error != null ? scheme.error : scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: expanded ? 'Свернуть' : 'Выбрать треки',
                  onPressed: () => picker.toggleExpanded(album.id),
                  icon: AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? TrackChecklist(picker: picker, albumId: album.id)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class TrackChecklist extends StatelessWidget {
  const TrackChecklist({super.key, required this.picker, required this.albumId, this.indent = 40});

  final ArtistPicker picker;
  final String albumId;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tracks = picker.tracks(albumId);
    final error = picker.error(albumId);
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(error, style: TextStyle(color: scheme.error, fontSize: 12.5)),
      );
    }
    if (tracks == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child:
            Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2))),
      );
    }
    return Container(
      margin: EdgeInsets.only(left: indent, bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final t in tracks)
            InkWell(
              onTap: () => picker.toggleTrack(albumId, t.id),
              child: Row(
                children: [
                  Checkbox(
                    visualDensity: VisualDensity.compact,
                    value: picker.trackSelected(albumId, t.id),
                    onChanged: (_) => picker.toggleTrack(albumId, t.id),
                  ),
                  SizedBox(
                    width: 22,
                    child: Text(
                      t.number > 0 ? '${t.number}' : '',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    child:
                        TitleWithBadge(t.title, explicit: t.explicit, style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
