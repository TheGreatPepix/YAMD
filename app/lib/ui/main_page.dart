import 'package:flutter/material.dart';

import '../state/controller.dart';
import '../state/models.dart';
import '../theme.dart';
import 'link_panel.dart';
import 'log_dialog.dart';
import 'queue.dart';
import 'settings_dialog.dart';
import 'widgets.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key, required this.c});

  final Controller c;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(c: c),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth >= 920) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 430, child: LinkPanel(c: c)),
                          const SizedBox(width: 20),
                          Expanded(child: QueuePanel(c: c)),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Column(
                      children: [
                        SizedBox(height: (box.maxHeight * 0.5).clamp(280.0, 460.0), child: LinkPanel(c: c)),
                        const SizedBox(height: 16),
                        Expanded(child: QueuePanel(c: c)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.c});

  final Controller c;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
      child: Row(
        children: [
          const BrandMark(size: 36),
          const SizedBox(width: 12),
          Text('YAMD', style: text.titleLarge),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ValueListenableBuilder(
                  valueListenable: c.stats, builder: (_, s, _) => _StatsPill(stats: s)),
            ),
          ),
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

class _StatsPill extends StatelessWidget {
  const _StatsPill({required this.stats});

  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: !stats.busy
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey('stats'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.south_rounded, size: 15, color: context.status.accent),
                  const SizedBox(width: 6),
                  Text(
                    '${formatBytes(stats.speed)}/с',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.status.accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '  ·  ${stats.active} в работе'
                      '${stats.queued > 0 ? ' · ${stats.queued} в очереди' : ''}',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
