import 'dart:io';

import 'package:flutter/services.dart';

class Desktop {
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

  void quit() => SystemNavigator.pop();
}
