import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/controller.dart';
import '../state/draft.dart';
import '../state/search.dart';
import '../theme.dart';
import 'widgets.dart';

class LinkInput extends StatefulWidget {
  const LinkInput({super.key, required this.c, this.hero = false});

  final Controller c;
  final bool hero;

  @override
  State<LinkInput> createState() => _LinkInputState();
}

class _LinkInputState extends State<LinkInput> {
  final _focus = FocusNode();

  Controller get c => widget.c;
  TextEditingController get _input => c.search.input;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    if (!looksLikeLinks(text)) {
      c.search.run(text);
      return;
    }
    _input.clear();
    c.search.close();
    c.addLinks(text);
    _focus.requestFocus();
  }

  void _clear() {
    _input.clear();
    c.search.close();
    _focus.requestFocus();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = (data?.text ?? '').trim();
    if (text.isEmpty) return;
    if (looksLikeLinks(text)) {
      c.addLinks(text);
      return;
    }
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
    c.search.run(text);
  }

  Future<void> _pasteInline() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = (data?.text ?? '').trim();
    if (text.isEmpty) return;
    final links = splitLinks(text);
    final link = looksLikeLinks(text);
    if (link && (text.contains('\n') || links.length > 1 || _input.text.trim().isEmpty)) {
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = context.status.accent;
    final hero = widget.hero;
    final phone = MediaQuery.sizeOf(context).width < phoneWidth;
    return ListenableBuilder(
      listenable: _input,
      builder: (context, _) {
        final text = _input.text.trim();
        final empty = text.isEmpty;
        final link = looksLikeLinks(text);
        final icon = empty
            ? Icons.content_paste_rounded
            : link
            ? Icons.add_rounded
            : Icons.search_rounded;
        final Widget action = hero && phone
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton.filled(
                  tooltip: empty
                      ? 'Вставить'
                      : link
                      ? 'Добавить'
                      : 'Найти',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(52, 44),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: empty ? _paste : _submit,
                  icon: Icon(icon, size: 20),
                ),
              )
            : hero
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: empty ? _paste : _submit,
                  icon: Icon(
                    empty
                        ? Icons.content_paste_rounded
                        : link
                        ? Icons.add_rounded
                        : Icons.search_rounded,
                    size: 18,
                  ),
                  label: Text(
                    empty
                        ? 'Вставить'
                        : link
                        ? 'Добавить'
                        : 'Найти',
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(right: 6),
                child: empty
                    ? IconButton(
                        tooltip: 'Вставить',
                        icon: const Icon(Icons.content_paste_rounded, size: 20),
                        onPressed: _paste,
                      )
                    : !link
                    ? IconButton(
                        tooltip: 'Очистить',
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: _clear,
                      )
                    : IconButton.filled(
                        tooltip: 'Добавить',
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          shape: const CircleBorder(),
                          fixedSize: const Size(32, 32),
                          minimumSize: const Size(32, 32),
                          padding: EdgeInsets.zero,
                        ),
                        iconSize: 20,
                        icon: const Icon(Icons.add_rounded),
                        onPressed: _submit,
                      ),
              );
        final radius = BorderRadius.circular(hero ? 16 : 12);
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (!empty) _clear();
            },
          },
          child: Actions(
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
              autofocus: !phone,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              style: TextStyle(fontSize: hero ? 16 : 14),
              decoration: InputDecoration(
                hintText: hero
                    ? 'Ссылка или название трека, альбома, исполнителя'
                    : 'Ссылки или поиск по Яндекс Музыке',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: hero ? 8 : 0),
                  child: Icon(link ? Icons.link_rounded : Icons.search_rounded),
                ),
                suffixIcon: action,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: hero ? 22 : 12),
                isDense: !hero,
                fillColor: hero ? scheme.surfaceContainerHigh : scheme.surfaceContainer,
                border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(color: hero ? accent : scheme.outlineVariant, width: hero ? 1.5 : 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: radius,
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
