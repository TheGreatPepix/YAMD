import 'package:flutter/material.dart';

import '../state/picker.dart';
import 'widgets.dart';

String ofReleases(int n) => '$n ${n % 10 == 1 && n % 100 != 11 ? 'релиза' : 'релизов'}';

String releasesLabel(int n) {
  final mod10 = n % 10, mod100 = n % 100;
  final word = (mod10 == 1 && mod100 != 11)
      ? 'релиз'
      : (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
          ? 'релиза'
          : 'релизов';
  return '$n $word';
}

class TrackChecklist extends StatelessWidget {
  const TrackChecklist({
    super.key,
    required this.picker,
    required this.albumId,
    this.indent = 40,
    this.showArtist = false,
  });

  final ArtistPicker picker;
  final String albumId;
  final double indent;
  final bool showArtist;

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
                  Container(
                    constraints: BoxConstraints(minWidth: MediaQuery.textScalerOf(context).scale(22)),
                    padding: const EdgeInsets.only(right: 6),
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
                  if (showArtist && t.artist.isNotEmpty)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          t.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                        ),
                      ),
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
