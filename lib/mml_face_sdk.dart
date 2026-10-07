library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'mml_face_sdk_platform_interface.dart';
import 'src/license.dart';
import 'src/model_pack.dart';
import 'src/types.dart';

export 'package:cryptography/cryptography.dart'
    show SimplePublicKey, KeyPairType;
export 'src/license.dart';
export 'src/liveness_decision.dart';
export 'src/model_pack.dart' show ModelPackDescriptor;
export 'src/preprocessing.dart';
export 'src/types.dart';

class MmlFaceSdk {
  MmlFaceSdk({
    required this.publicLicenseKey,
    this.matchThreshold = 0.70,
    LicenseClock? clock,
  }) : _clock = clock ?? const SystemLicenseClock();

  final SimplePublicKey publicLicenseKey;
  final double matchThreshold;
  final LicenseClock _clock;
  LicenseClaims? _license;

  static const currentModelPackVersion = '1';

  bool get isLicensed => _license != null;

  Future<DeviceBinding> deviceBinding() async {
    final raw = await MmlFaceSdkPlatform.instance.getDeviceBinding();
    return DeviceBinding(
      appId: raw['appId']! as String,
      deviceId: raw['deviceId']! as String,
      platform: raw['platform']! as String,
    );
  }

  Future<LicenseClaims> initialize({required String license}) async {
    final binding = await deviceBinding();
    final claims = await OfflineLicenseValidator(
      publicKey: publicLicenseKey,
      clock: _clock,
    ).validate(license, binding: binding);
    if (!await MmlFaceSdkPlatform.instance.hasModelPack(
      currentModelPackVersion,
    )) {
      throw const FaceSdkException(
        FaceSdkError.modelUnavailable,
        'The private model pack has not been installed.',
      );
    }
    _license = claims;
    return _license!;
  }

  Future<String> activate({
    required Uri endpoint,
    required String activationCode,
  }) async {
    final binding = await deviceBinding();
    final activation = await LicenseActivator().activate(
      endpoint: endpoint,
      activationCode: activationCode,
      binding: binding,
    );
    await OfflineLicenseValidator(
      publicKey: publicLicenseKey,
      clock: _clock,
    ).validate(activation.license, binding: binding);
    await ModelPackInstaller().downloadAndInstall(activation.modelPack);
    await initialize(license: activation.license);
    return activation.license;
  }

  Future<FaceTemplate> createTemplate(Uint8List encodedImage) async {
    _requireLicense();
    final raw = await _native(
      () => MmlFaceSdkPlatform.instance.createTemplate(encodedImage),
    );
    return FaceTemplate.fromNative(raw);
  }

  Future<VerificationResult> recognize({
    required Uint8List encodedImage,
    required FaceTemplate template,
  }) => _compare(encodedImage, template, liveness: false);

  Future<VerificationResult> verify({
    required Uint8List encodedImage,
    required FaceTemplate template,
  }) => _compare(encodedImage, template, liveness: true);

  Future<VerificationResult> _compare(
    Uint8List image,
    FaceTemplate template, {
    required bool liveness,
  }) async {
    _requireLicense();
    if (template.embedding.isEmpty ||
        template.embedding.any((value) => !value.isFinite)) {
      throw const FaceSdkException(
        FaceSdkError.templateIncompatible,
        'Template contains invalid values.',
      );
    }
    if (template.modelId != FaceTemplate.currentModelId) {
      throw const FaceSdkException(
        FaceSdkError.templateIncompatible,
        'Template was created with an incompatible model.',
      );
    }
    final raw = await _native(
      () => MmlFaceSdkPlatform.instance.verify(
        image,
        template.embedding,
        liveness: liveness,
      ),
    );
    final similarity = (raw['similarity'] as num?)?.toDouble();
    return VerificationResult(
      matched:
          similarity != null &&
          similarity >= matchThreshold &&
          (!liveness || raw['livenessPassed'] == true),
      similarity: similarity,
      livenessRequired: liveness,
      livenessPassed: raw['livenessPassed'] as bool?,
      livenessScore: (raw['livenessScore'] as num?)?.toDouble(),
      spoofLatched: raw['spoofLatched'] as bool? ?? false,
      quality: FaceQuality.fromNative(raw),
    );
  }

  Future<void> resetLiveness() => MmlFaceSdkPlatform.instance.resetLiveness();
  Future<void> dispose() => MmlFaceSdkPlatform.instance.dispose();

  void _requireLicense() {
    final license = _license;
    if (license == null ||
        (!license.isPerpetual && !_clock.now().isBefore(license.expiresAt!))) {
      throw const FaceSdkException(
        FaceSdkError.licenseInvalid,
        'A valid SDK licence is required.',
      );
    }
  }

  Future<Map<Object?, Object?>> _native(
    Future<Map<Object?, Object?>> Function() operation,
  ) async {
    try {
      return await operation();
    } catch (error) {
      final text = error.toString();
      final code = FaceSdkError.values.firstWhere(
        (value) => text.contains(value.name),
        orElse: () => FaceSdkError.internal,
      );
      throw FaceSdkException(code, 'Face operation failed.');
    }
  }
}
