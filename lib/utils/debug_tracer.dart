import 'dart:collection';

/// In-memory ring buffer for exhaustive debug tracing.
/// Works in both the UI isolate and the background isolate independently.
class DebugTracer {
  static final DebugTracer instance = DebugTracer._();
  DebugTracer._();

  static const int _maxLines = 2000;
  final _buffer = Queue<String>();

  /// Sequence counter so we can spot gaps / ordering issues.
  int _seq = 0;

  void log(String tag, String message) {
    _seq++;
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
    final line = '[$_seq][$ts][$tag] $message';
    _buffer.addLast(line);
    while (_buffer.length > _maxLines) {
      _buffer.removeFirst();
    }
  }

  /// Returns all buffered lines joined with newlines.
  String dump() => _buffer.join('\n');

  /// Returns all buffered lines as a list.
  List<String> lines() => _buffer.toList();

  void clear() {
    _buffer.clear();
    _seq = 0;
  }

  int get length => _buffer.length;
}
