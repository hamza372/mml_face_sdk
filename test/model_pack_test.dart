import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:everif_face_sdk/everif_face_sdk_platform_interface.dart';
import 'package:everif_face_sdk/src/model_pack.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class InstallingPlatform extends EverifFaceSdkPlatform
    with MockPlatformInterfaceMixin {
  String? version;
  Map<String, Uint8List>? models;

  @override
  Future<void> installModelPack(
    String modelVersion,
    Map<String, Uint8List> modelFiles,
  ) async {
    version = modelVersion;
    models = modelFiles;
  }
}

void main() {
  test('decrypts, verifies, and installs the private model pack', () async {
    final archive = Archive();
    for (final name in ModelPackInstaller.requiredModels) {
      archive.addFile(ArchiveFile(name, 3, [1, 2, 3]));
    }
    final clear = ZipEncoder().encodeBytes(archive);
    final digest = await Sha256().hash(clear);
    final checksum = digest.bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
    final box = await AesGcm.with256bits().encrypt(
      clear,
      secretKey: SecretKey(key),
      nonce: List<int>.generate(12, (index) => index),
    );
    final responseBytes = Uint8List.fromList([
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
    final platform = InstallingPlatform();
    EverifFaceSdkPlatform.instance = platform;

    await ModelPackInstaller(
      client: MockClient((_) async => http.Response.bytes(responseBytes, 200)),
    ).downloadAndInstall(
      ModelPackDescriptor(
        version: '1',
        downloadUrl: Uri.parse('https://license.example/model-pack/grant'),
        key: key,
        plaintextSha256: checksum,
      ),
    );

    expect(platform.version, '1');
    expect(platform.models?.keys.toSet(), ModelPackInstaller.requiredModels);
  });
}
