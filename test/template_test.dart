import 'package:mml_face_sdk/mml_face_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('template envelope round trips', () {
    final source = FaceTemplate(
      embedding: const [.6, .8],
      createdAt: DateTime.utc(2026),
    );
    final decoded = FaceTemplate.fromJson(source.toJson());
    expect(decoded.embedding, source.embedding);
    expect(decoded.modelId, FaceTemplate.currentModelId);
  });
  test(
    'rejects malformed template',
    () => expect(
      () => FaceTemplate.fromJson({
        'version': 1,
        'modelId': 'x',
        'createdAt': '2026-01-01',
        'embedding': [double.nan],
      }),
      throwsA(isA<FaceSdkException>()),
    ),
  );
}
