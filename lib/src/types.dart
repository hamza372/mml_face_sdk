enum FaceSdkError {
  invalidImage,
  noFace,
  multipleFaces,
  faceTooSmall,
  faceNotFrontal,
  landmarksMissing,
  poorQuality,
  spoofDetected,
  livenessPending,
  templateIncompatible,
  licenseInvalid,
  modelUnavailable,
  busy,
  internal,
}

class FaceSdkException implements Exception {
  const FaceSdkException(this.code, this.message);
  final FaceSdkError code;
  final String message;
  @override
  String toString() => 'FaceSdkException(${code.name}): $message';
}

class FaceTemplate {
  const FaceTemplate({
    required this.embedding,
    this.modelId = currentModelId,
    required this.createdAt,
  });
  static const currentModelId = 'mobileFaceNetARCNET-sha256-dfac9cfe-v1';
  final List<double> embedding;
  final String modelId;
  final DateTime createdAt;
  factory FaceTemplate.fromNative(Map<Object?, Object?> raw) => FaceTemplate(
    embedding: (raw['embedding']! as List)
        .cast<num>()
        .map((value) => value.toDouble())
        .toList(growable: false),
    createdAt: DateTime.now().toUtc(),
  );
  Map<String, Object> toJson() => {
    'version': 1,
    'modelId': modelId,
    'createdAt': createdAt.toIso8601String(),
    'embedding': embedding,
  };
  factory FaceTemplate.fromJson(Map<String, Object?> json) {
    final values = (json['embedding'] as List?)?.cast<num>();
    if (json['version'] != 1 ||
        json['modelId'] is! String ||
        values == null ||
        values.isEmpty ||
        values.any((v) => !v.isFinite)) {
      throw const FaceSdkException(
        FaceSdkError.templateIncompatible,
        'Invalid template envelope.',
      );
    }
    return FaceTemplate(
      embedding: values.map((v) => v.toDouble()).toList(growable: false),
      modelId: json['modelId']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
    );
  }
}

class FaceQuality {
  const FaceQuality({
    required this.faceRatio,
    required this.yaw,
    required this.roll,
  });
  final double faceRatio;
  final double yaw;
  final double roll;
  factory FaceQuality.fromNative(Map<Object?, Object?> raw) => FaceQuality(
    faceRatio: (raw['faceRatio'] as num?)?.toDouble() ?? 0,
    yaw: (raw['yaw'] as num?)?.toDouble() ?? 0,
    roll: (raw['roll'] as num?)?.toDouble() ?? 0,
  );
}

class VerificationResult {
  const VerificationResult({
    required this.matched,
    required this.similarity,
    required this.livenessRequired,
    required this.livenessPassed,
    required this.livenessScore,
    required this.spoofLatched,
    required this.quality,
  });
  final bool matched;
  final double? similarity;
  final bool livenessRequired;
  final bool? livenessPassed;
  final double? livenessScore;
  final bool spoofLatched;
  final FaceQuality quality;
}
