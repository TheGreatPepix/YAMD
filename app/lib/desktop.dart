import 'dart:io';

import 'package:flutter/services.dart';

class Desktop {
  Desktop({this.args = const []});

  static const restartFlag = '--restart';
  static const _channel = MethodChannel('yamd/desktop');
  static const _android = MethodChannel('yamd/android');

  bool get canReveal => !Platform.isAndroid;

  Future<bool> storageGranted() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _android.invokeMethod<bool>('storageGranted') ?? true;
    } on MissingPluginException {
      return true;
    }
  }

  Future<void> requestStorage() async {
    if (!Platform.isAndroid) return;
    try {
      await _android.invokeMethod<void>('requestStorage');
    } on MissingPluginException {
      return;
    }
  }

  final List<String> args;

  Future<void> _call(String method, [Object? args]) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      return;
    }
  }

  void listen({required VoidCallback exit}) {
    if (!Platform.isWindows) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'exit') exit();
    });
    _call('tray', {'open': 'Открыть YAMD', 'exit': 'Выход'});
  }

  void showWindow() => _call('show');

  void open(String target) {
    if (Platform.isAndroid) {
      _android.invokeMethod<bool>('open', target);
      return;
    }
    if (Platform.isWindows) {
      if (target.startsWith('http')) {
        Process.run('rundll32', ['url.dll,FileProtocolHandler', target]);
      } else {
        Process.run('explorer.exe', [target]);
      }
      return;
    }
    Process.run(Platform.isMacOS ? 'open' : 'xdg-open', [target]);
  }

  void reveal(String file) {
    if (Platform.isAndroid) return;
    if (Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', file]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', file]);
    } else {
      open(File(file).parent.path);
    }
  }

  Future<void> quit() async {
    if (Platform.isAndroid) {
      await SystemNavigator.pop();
      return;
    }
    if (Platform.isWindows) {
      try {
        await _channel.invokeMethod<void>('quit');
        return;
      } on MissingPluginException {
        exit(0);
      }
    }
    exit(0);
  }

  Future<void> restart() async {
    if (Platform.isAndroid) {
      exit(0);
    }
    final exe = Platform.environment['APPIMAGE'] ?? Platform.resolvedExecutable;
    final next = [...args.where((a) => a != restartFlag), restartFlag];
    await Process.start(exe, next, mode: ProcessStartMode.detached);
    exit(0);
  }
}
