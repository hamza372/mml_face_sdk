import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mml_face_sdk_platform_interface.dart';

class MethodChannelMmlFaceSdk extends MmlFaceSdkPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('mml_face_sdk');

  @override
  Future<Map<Object?, Object?>> createTemplate(Uint8List image) async =>
      (await methodChannel.invokeMapMethod<Object?, Object?>('createTemplate', {
        'image': image,
      }))!;

  @override
  Future<Map<Object?, Object?>> createTemplateFrame(
    Uint8List nv21,
    int width,
    int height,
    int rotationDegrees,
  ) async => (await methodChannel.invokeMapMethod<Object?, Object?>(
    'createTemplateFrame',
    {
      'nv21': nv21,
      'width': width,
      'height': height,
      'rotationDegrees': rotationDegrees,
    },
  ))!;

  @override
  Future<Map<Object?, Object?>> verify(
    Uint8List image,
    List<double> template, {
    required bool liveness,
  }) async => (await methodChannel.invokeMapMethod<Object?, Object?>('verify', {
    'image': image,
    'template': template,
    'liveness': liveness,
  }))!;

  @override
  Future<Map<Object?, Object?>> verifyFrame(
    Uint8List nv21,
    int width,
    int height,
    int rotationDegrees,
    List<double> template, {
    required bool liveness,
  }) async =>
      (await methodChannel.invokeMapMethod<Object?, Object?>('verifyFrame', {
        'nv21': nv21,
        'width': width,
        'height': height,
        'rotationDegrees': rotationDegrees,
        'template': template,
        'liveness': liveness,
      }))!;

  @override
  Future<Map<Object?, Object?>> getDeviceBinding() async => (await methodChannel
      .invokeMapMethod<Object?, Object?>('getDeviceBinding'))!;

  @override
  Future<bool> hasModelPack(String version) async =>
      await methodChannel.invokeMethod<bool>('hasModelPack', {
        'version': version,
      }) ??
      false;

  @override
  Future<void> installModelPack(
    String version,
    Map<String, Uint8List> models,
  ) => methodChannel.invokeMethod('installModelPack', {
    'version': version,
    'models': models,
  });

  @override
  Future<void> resetLiveness() => methodChannel.invokeMethod('resetLiveness');

  @override
  Future<void> dispose() => methodChannel.invokeMethod('dispose');
}
