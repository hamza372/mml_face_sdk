import 'dart:math' as math;
import 'dart:typed_data';

/// Reference routines used for compatibility tests. Native engines implement
/// the same channel order and values without moving image data through Dart.
abstract final class CompatibilityPreprocessing {
  static Float32List miniFasBgr(Iterable<(int, int, int)> rgbPixels) {
    final values = Float32List(rgbPixels.length * 3);
    var i = 0;
    for (final (r, g, b) in rgbPixels) {
      values[i++] = b.toDouble();
      values[i++] = g.toDouble();
      values[i++] = r.toDouble();
    }
    return values;
  }

  static Float32List arcFaceBgr(Iterable<(int, int, int)> rgbPixels) {
    final values = Float32List(rgbPixels.length * 3);
    var i = 0;
    for (final (r, g, b) in rgbPixels) {
      values[i++] = (b - 127.5) / 128;
      values[i++] = (g - 127.5) / 128;
      values[i++] = (r - 127.5) / 128;
    }
    return values;
  }

  static List<double> classProbabilities(List<double> output) {
    if (output.length != 3 || output.any((value) => !value.isFinite)) {
      throw StateError('Invalid MiniFAS output.');
    }
    final sum = output.reduce((a, b) => a + b);
    if (output.every((value) => value >= 0 && value <= 1) &&
        (sum - 1).abs() < .001) {
      return List.unmodifiable(output);
    }
    final maximum = output.reduce(math.max);
    final exponentials = output.map((value) => math.exp(value - maximum));
    final denominator = exponentials.reduce((a, b) => a + b);
    return exponentials.map((value) => value / denominator).toList();
  }

  static double fusedLiveScore(List<double> first, List<double> second) =>
      (classProbabilities(first)[1] + classProbabilities(second)[1]) / 2;
}
