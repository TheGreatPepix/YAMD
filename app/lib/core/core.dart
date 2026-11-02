import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef Event = Map<String, dynamic>;

abstract class Core {
  Stream<Event> get events;
  void send(Map<String, Object?> command);
  Future<void> close();
}

class ProcessCore implements Core {
  ProcessCore._(this._process) {
    _process.stdin.encoding = utf8;
    _process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_line, onDone: _ended);
    _process.stderr.drain<void>();
  }

  final Process _process;
  final _events = StreamController<Event>();
  var _closed = false;

  static Future<ProcessCore> start(String exe) async {
    final process = await Process.start(exe, []);
    return ProcessCore._(process);
  }

  static String? beside(String windowExe) {
    final dir = File(windowExe).parent.path;
    for (final name in ['ymcore.exe', 'ymcore']) {
      final path = '$dir${Platform.pathSeparator}$name';
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  @override
  Stream<Event> get events => _events.stream;

  void _line(String line) {
    final Object? event;
    try {
      event = jsonDecode(line);
    } on FormatException {
      return;
    }
    if (event is Event) _events.add(event);
  }

  Future<void> _ended() async {
    final code = await _process.exitCode;
    _events.add({'type': 'coreExited', 'code': code});
    await _events.close();
  }

  @override
  void send(Map<String, Object?> command) {
    if (_closed) return;
    _process.stdin.writeln(jsonEncode(command));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _process.stdin.close();
    await _process.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _process.kill();
        return -1;
      },
    );
  }
}
