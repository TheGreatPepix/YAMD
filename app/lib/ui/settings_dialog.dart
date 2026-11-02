import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../state/controller.dart';
import '../state/models.dart';
import '../theme.dart';

Future<void> showSettingsDialog(BuildContext context, Controller c) {
  return showDialog(context: context, builder: (_) => _SettingsDialog(c: c));
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({required this.c});

  final Controller c;

  Future<void> _browse() async {
    final path = await getDirectoryPath(initialDirectory: c.dir.isEmpty ? null : c.dir);
    if (path != null) c.setDir(path);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Настройки', style: text.titleLarge)),
                    IconButton(
                      tooltip: 'Закрыть',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _Label('Папка для загрузок'),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_rounded, size: 20, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Tooltip(
                          message: c.dir,
                          child: Text(c.dir, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Открыть',
                        icon: const Icon(Icons.open_in_new_rounded, size: 20),
                        onPressed: c.dir.isEmpty ? null : () => c.openFolder(c.dir),
                      ),
                      FilledButton.tonal(onPressed: _browse, child: const Text('Изменить')),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const _Label('Качество'),
                SegmentedButton<Quality>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: Quality.lossless,
                      icon: Icon(Icons.graphic_eq_rounded),
                      label: Text('FLAC (без потерь)'),
                    ),
                    ButtonSegment(
                      value: Quality.mp3,
                      icon: Icon(Icons.music_note_rounded),
                      label: Text('MP3 320'),
                    ),
                  ],
                  selected: {c.quality},
                  onSelectionChanged: (s) => c.setQuality(s.first),
                ),
                const SizedBox(height: 8),
                _Hint(
                  c.quality == Quality.lossless
                      ? 'FLAC до 24 бит / 192 кГц. Если у трека нет lossless-версии, скачается MP3 320.'
                      : 'MP3 лучшего доступного битрейта, файлы в 3-5 раз меньше FLAC.',
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(child: _Label('Одновременных загрузок')),
                    Text(
                      '${c.concurrency}',
                      style: text.titleMedium?.copyWith(color: context.status.accent),
                    ),
                  ],
                ),
                Slider(
                  min: 1,
                  max: 8,
                  divisions: 7,
                  value: c.concurrency.toDouble().clamp(1, 8),
                  label: '${c.concurrency}',
                  onChanged: (v) => c.setConcurrency(v.round()),
                ),
                const _Hint(
                  'Сколько треков качается параллельно во всех заданиях сразу. '
                  'Меняется на лету, без остановки загрузок.',
                ),
                const SizedBox(height: 22),
                const _Label('Тема'),
                SegmentedButton<ThemeChoice>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeChoice.system,
                      icon: Icon(Icons.brightness_auto_rounded),
                      label: Text('Системная'),
                    ),
                    ButtonSegment(
                      value: ThemeChoice.light,
                      icon: Icon(Icons.light_mode_rounded),
                      label: Text('Светлая'),
                    ),
                    ButtonSegment(
                      value: ThemeChoice.dark,
                      icon: Icon(Icons.dark_mode_rounded),
                      label: Text('Тёмная'),
                    ),
                  ],
                  selected: {c.theme},
                  onSelectionChanged: (s) => c.setTheme(s.first),
                ),
                const SizedBox(height: 22),
                if (c.version.isNotEmpty)
                  Text(
                    'Версия ${c.version}',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 12.5, height: 1.4, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
