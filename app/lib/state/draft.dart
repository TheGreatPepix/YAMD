import 'package:flutter/foundation.dart';

import 'models.dart';
import 'picker.dart';

final _separators = RegExp(r'[\s,;]+');
final _digits = RegExp(r'^\d+$');

List<String> splitLinks(String text) {
  final tokens = text.split(_separators).where((t) => t.isNotEmpty);
  final links = [
    for (final t in tokens)
      if (t.contains('yandex.') || t.contains('://') || _digits.hasMatch(t)) t,
  ];
  if (links.isEmpty && text.trim().isNotEmpty) return [text.trim()];
  return links.toSet().toList();
}

class Draft extends ChangeNotifier {
  Draft(this.link) : preview = Preview(link: link, status: PreviewStatus.loading);

  final String link;
  Preview preview;
  ArtistPicker? picker;
  var pickerOpen = false;

  bool get loading => preview.status == PreviewStatus.loading;
  bool get failed => preview.status == PreviewStatus.error;
  bool get ready => preview.status == PreviewStatus.ok && !(picker?.nothing ?? false);

  int get trackCount => picker?.trackCount ?? preview.count;

  List<Map<String, Object?>>? get selection {
    final p = picker;
    return p == null || p.everything ? null : p.selection();
  }

  void apply(Preview p, void Function(String albumId) load) {
    preview = p;
    picker?.removeListener(notifyListeners);
    picker?.dispose();
    picker = p.status == PreviewStatus.ok && p.albums.isNotEmpty
        ? (ArtistPicker(p.albums, load: load)..addListener(notifyListeners))
        : null;
    final pk = picker;
    if (pk != null && p.kind == ReleaseKind.album) pk.toggleExpanded(pk.albums.first.id);
    notifyListeners();
  }

  void togglePicker() {
    pickerOpen = !pickerOpen;
    final p = picker;
    if (pickerOpen && p != null && preview.kind == ReleaseKind.album) {
      final id = p.albums.first.id;
      if (!p.isExpanded(id)) p.toggleExpanded(id);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    picker?.removeListener(notifyListeners);
    picker?.dispose();
    super.dispose();
  }
}
