import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/controller.dart';
import '../state/draft.dart';
import '../theme.dart';

class LinkInput extends StatefulWidget {
  const LinkInput({super.key, required this.c, this.hero = false});

  final Controller c;
  final bool hero;

  @override
  State<LinkInput> createState() => _LinkInputState();
}

class _LinkInputState extends State<LinkInput> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  Controller get c => widget.c;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _input.text;
    _input.clear();
    if (text.trim().isEmpty) return;
    c.addLinks(text);
    _focus.requestFocus();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isNotEmpty) c.addLinks(text);
  }

  Future<void> _pasteInline() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = (data?.text ?? '').trim();
    if (text.isEmpty) return;
    final links = splitLinks(text);
    final link = links.any((l) => l.contains('yandex.') || l.contains('://'));
    if (text.contains('\n') || links.length > 1 || (link && _input.text.trim().isEmpty)) {
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
    return ListenableBuilder(
      listenable: _input,
      builder: (context, _) {
        final empty = _input.text.trim().isEmpty;
        final Widget action = hero
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: empty ? _paste : _submit,
                  icon: Icon(empty ? Icons.content_paste_rounded : Icons.add_rounded, size: 18),
                  label: Text(empty ? 'Вставить' : 'Добавить'),
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
        return Actions(
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
            style: TextStyle(fontSize: hero ? 16 : 14),
            decoration: InputDecoration(
              hintText:
                  hero ? 'Ссылка на трек, альбом, плейлист или исполнителя' : 'Ссылки на треки, альбомы, плейлисты, исполнителей',
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: hero ? 8 : 0),
                child: const Icon(Icons.link_rounded),
              ),
              suffixIcon: action,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: hero ? 22 : 12),
              isDense: !hero,
              fillColor: hero ? scheme.surfaceContainerHigh : scheme.surfaceContainer,
              border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide:
                    BorderSide(color: hero ? accent : scheme.outlineVariant, width: hero ? 1.5 : 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: BorderSide(color: accent, width: 1.5),
              ),
            ),
          ),
        );
      },
    );
  }
}
