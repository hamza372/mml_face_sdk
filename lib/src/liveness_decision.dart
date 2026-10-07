import 'dart:collection';

/// Compatibility baseline only; calibrate thresholds on representative data.
class PassiveLivenessDecision {
  static const windowSize = 4;
  static const liveThreshold = 0.75;
  static const spoofRunThreshold = 0.40;
  static const spoofRunLength = 3;
  static const spoofRunSpan = Duration(milliseconds: 600);
  final Queue<double> _scores = Queue<double>();
  int _lowRun = 0;
  DateTime? _lowRunStarted;
  bool _latched = false;
  bool get spoofLatched => _latched;
  bool get ready => _scores.length == windowSize;
  double? get median {
    if (_scores.isEmpty) return null;
    final v = _scores.toList()..sort();
    return v.length.isOdd
        ? v[v.length ~/ 2]
        : (v[v.length ~/ 2 - 1] + v[v.length ~/ 2]) / 2;
  }

  bool get isLive => ready && !_latched && median! >= liveThreshold;
  void add(double value, DateTime time) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw ArgumentError.value(value, 'value');
    }
    _scores.addLast(value);
    if (_scores.length > windowSize) _scores.removeFirst();
    if (value < spoofRunThreshold) {
      _lowRunStarted ??= time;
      _lowRun++;
      if (_lowRun >= spoofRunLength &&
          time.difference(_lowRunStarted!) >= spoofRunSpan) {
        _latched = true;
      }
    } else {
      _lowRun = 0;
      _lowRunStarted = null;
    }
  }

  void clearWindow() {
    _scores.clear();
    _lowRun = 0;
    _lowRunStarted = null;
  }

  void reset() {
    clearWindow();
    _latched = false;
  }
}
