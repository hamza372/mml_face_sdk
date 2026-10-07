import 'package:mml_face_sdk/mml_face_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MiniFAS packs raw BGR', () {
    expect(CompatibilityPreprocessing.miniFasBgr([(10, 20, 30)]), [30, 20, 10]);
  });
  test('ArcFace packs normalized BGR using 127.5 and 128', () {
    final value = CompatibilityPreprocessing.arcFaceBgr([(255, 127, 0)]);
    expect(value[0], closeTo(-0.99609375, 1e-7));
    expect(value[1], closeTo(-0.00390625, 1e-7));
    expect(value[2], closeTo(0.99609375, 1e-7));
  });
  test('fuses class-1 probabilities after softmax', () {
    final score = CompatibilityPreprocessing.fusedLiveScore(
      [0, 2, 0],
      [.1, .8, .1],
    );
    expect(score, closeTo((0.786986 + .8) / 2, 1e-5));
  });
}
