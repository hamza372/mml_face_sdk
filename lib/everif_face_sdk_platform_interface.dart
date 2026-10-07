import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'everif_face_sdk_method_channel.dart';

abstract class EverifFaceSdkPlatform extends PlatformInterface {
  EverifFaceSdkPlatform() : super(token: _token);
  static final Object _token = Object();
  static EverifFaceSdkPlatform _instance = MethodChannelEverifFaceSdk();
  static EverifFaceSdkPlatform get instance => _instance;
  static set instance(EverifFaceSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<Map<Object?, Object?>> createTemplate(Uint8List image) =>
      throw UnimplementedError();
  Future<Map<Object?, Object?>> verify(
    Uint8List image,
    List<double> template, {
    required bool liveness,
  }) => throw UnimplementedError();
  Future<Map<Object?, Object?>> getDeviceBinding() =>
      throw UnimplementedError();
  Future<bool> hasModelPack(String version) => throw UnimplementedError();
  Future<void> installModelPack(
    String version,
    Map<String, Uint8List> models,
  ) => throw UnimplementedError();
  Future<void> resetLiveness() => throw UnimplementedError();
  Future<void> dispose() => throw UnimplementedError();
}
