import 'package:everif_face_sdk/everif_face_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('four-frame median uses compatibility threshold', () {
    final d = PassiveLivenessDecision();
    final t = DateTime.utc(2026);
    for (final value in [0.74, 0.76, 0.80, 0.75]) {
      d.add(value, t);
    }
    expect(d.ready, isTrue);
    expect(d.median, closeTo(0.755, 1e-9));
    expect(d.isLive, isTrue);
  });
  test('spoof run latches and clearWindow does not release it', () {
    final d = PassiveLivenessDecision();
    final t = DateTime.utc(2026);
    d.add(.2, t);
    d.add(.3, t.add(const Duration(milliseconds: 300)));
    d.add(.1, t.add(const Duration(milliseconds: 600)));
    expect(d.spoofLatched, isTrue);
    d.clearWindow();
    expect(d.spoofLatched, isTrue);
    d.reset();
    expect(d.spoofLatched, isFalse);
  });
}
