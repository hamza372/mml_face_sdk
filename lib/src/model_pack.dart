import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../mml_face_sdk_platform_interface.dart';
import 'types.dart';

class ModelPackDescriptor {
  const ModelPackDescriptor({
    required this.version,
    required this.downloadUrl,
    required this.key,
    required this.plaintextSha256,
  });

  final String version;
  final Uri downloadUrl;
  final Uint8List key;
  final String plaintextSha256;

  factory ModelPackDescriptor.fromJson(Map<String, dynamic> json) {
    final key = Uint8List.fromList(
      base64Url.decode(base64Url.normalize(json['key'] as String)),
    );
    if (key.length != 32) throw const FormatException('Invalid key length.');
    return ModelPackDescriptor(
      version: json['version'] as String,
      downloadUrl: Uri.parse(json['url'] as String),
      key: key,
      plaintextSha256: json['sha256'] as String,
    );
  }
}

class ModelPackInstaller {
  ModelPackInstaller({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const requiredModels = <String>{
    'mobileFaceNetARCNET.tflite',
    'minifas_v2_2.7_80.tflite',
    'minifas_v1se_4.0_80.tflite',
  };

  Future<void> downloadAndInstall(ModelPackDescriptor descriptor) async {
    if (descriptor.version != '1') {
      throw const FaceSdkException(
        FaceSdkError.modelUnavailable,
        'The server supplied an unsupported model pack.',
      );
    }
    try {
      final response = await _client.get(descriptor.downloadUrl);
      if (response.statusCode != 200 || response.bodyBytes.length < 29) {
        throw const FormatException('Download rejected.');
      }
      final sealed = response.bodyBytes;
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          sealed.sublist(12, sealed.length - 16),
          nonce: sealed.sublist(0, 12),
          mac: Mac(sealed.sublist(sealed.length - 16)),
        ),
        secretKey: SecretKey(descriptor.key),
      );
      final digest = await Sha256().hash(clear);
      final actual = digest.bytes
          .map((value) => value.toRadixString(16).padLeft(2, '0'))
          .join();
      if (actual != descriptor.plaintextSha256.toLowerCase()) {
        throw const FormatException('Model pack checksum mismatch.');
      }
      final archive = ZipDecoder().decodeBytes(clear, verify: true);
      final models = <String, Uint8List>{};
      for (final file in archive.files.where((file) => file.isFile)) {
        final name = file.name.split('/').last;
        if (requiredModels.contains(name)) {
          models[name] = Uint8List.fromList(file.content as List<int>);
        }
      }
      if (!models.keys.toSet().containsAll(requiredModels) ||
          models.length != requiredModels.length) {
        throw const FormatException('Model pack is incomplete.');
      }
      await MmlFaceSdkPlatform.instance.installModelPack(
        descriptor.version,
        models,
      );
    } catch (error) {
      if (error is FaceSdkException) rethrow;
      throw const FaceSdkException(
        FaceSdkError.modelUnavailable,
        'The private model pack could not be installed.',
      );
    }
  }
}
