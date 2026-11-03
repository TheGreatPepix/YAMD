import 'dart:io';

class Desktop {
  Desktop({this.args = const []});

  final List<String> args;

  void open(String target) {
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
    if (Platform.isWindows) {
      Process.run('explorer.exe', ['/select,', file]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', file]);
    } else {
      open(File(file).parent.path);
    }
  }

  void quit() => exit(0);

  Future<void> restart() async {
    final exe = Platform.environment['APPIMAGE'] ?? Platform.resolvedExecutable;
    await Process.start(exe, args, mode: ProcessStartMode.detached);
    exit(0);
  }
}
