import 'dart:async';

import 'package:flutter/material.dart';

import 'state/controller.dart';
import 'state/models.dart';
import 'theme.dart';
import 'ui/login_page.dart';
import 'ui/main_page.dart';
import 'ui/widgets.dart';

class YmdApp extends StatefulWidget {
  const YmdApp({super.key, required this.controller});

  final Controller controller;

  @override
  State<YmdApp> createState() => _YmdAppState();
}

class _YmdAppState extends State<YmdApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Notice>? _notices;

  Controller get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _notices = c.notices.listen(_showNotice);
    c.start();
  }

  @override
  void dispose() {
    _notices?.cancel();
    super.dispose();
  }

  void _showNotice(Notice n) {
    final messenger = _messenger.currentState;
    if (messenger == null) return;
    final ctx = messenger.context;
    final scheme = Theme.of(ctx).colorScheme;
    final (icon, color) = switch (n.kind) {
      NoticeKind.error => (Icons.error_rounded, scheme.error),
      NoticeKind.ok => (Icons.check_circle_rounded, ctx.status.success),
      NoticeKind.info => (Icons.info_rounded, scheme.primary),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: scheme.surfaceContainerHighest,
          content: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(n.message, style: TextStyle(color: scheme.onSurface))),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return MaterialApp(
          title: 'YAMD',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _messenger,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: switch (c.theme) {
            ThemeChoice.light => ThemeMode.light,
            ThemeChoice.dark => ThemeMode.dark,
            ThemeChoice.system => ThemeMode.system,
          },
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween(begin: 0.985, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: _screen(),
          ),
        );
      },
    );
  }

  Widget _screen() {
    if (c.fatal != null) return _Fatal(key: const ValueKey('fatal'), message: c.fatal!);

    final restoring = c.account.status == AccountStatus.checking && c.account.login.isEmpty;
    if (!c.ready) return const _Splash(key: ValueKey('splash'));
    if (c.canDownload) return MainPage(key: const ValueKey('main'), c: c);
    if (restoring && !_loginShown) return const _Splash(key: ValueKey('splash'));
    _loginShown = true;
    return LoginPage(key: const ValueKey('login'), c: c);
  }

  var _loginShown = false;
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 56),
            SizedBox(height: 24),
            SizedBox(width: 120, child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

class _Fatal extends StatelessWidget {
  const _Fatal({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 52, color: scheme.error),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
