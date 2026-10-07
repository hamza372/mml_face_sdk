import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:everif_face_sdk/everif_face_sdk.dart';
import 'package:everif_face_sdk/everif_face_sdk_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePlatform extends EverifFaceSdkPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<Map<Object?, Object?>> createTemplate(Uint8List image) async => {
    'embedding': [.6, .8],
    'faceRatio': .5,
    'yaw': 0,
    'roll': 0,
  };
  @override
  Future<void> dispose() async {}
  @override
  Future<Map<Object?, Object?>> getDeviceBinding() async => {
    'appId': 'a',
    'deviceId': 'd',
    'platform': 'ios',
  };
  @override
  Future<void> resetLiveness() async {}
  @override
  Future<Map<Object?, Object?>> verify(
    Uint8List image,
    List<double> template, {
    required bool liveness,
  }) async => {
    'similarity': .71,
    'livenessPassed': liveness ? true : null,
    'faceRatio': .5,
    'yaw': 0,
    'roll': 0,
  };
}

void main() {
  test('inference is denied before licence validation', () async {
    EverifFaceSdkPlatform.instance = FakePlatform();
    final keys = await Ed25519().newKeyPair();
    final sdk = EverifFaceSdk(publicLicenseKey: await keys.extractPublicKey());
    expect(
      () => sdk.createTemplate(Uint8List(1)),
      throwsA(isA<FaceSdkException>()),
    );
  });
}
