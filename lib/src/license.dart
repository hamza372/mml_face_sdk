import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import 'types.dart';

class DeviceBinding {
  const DeviceBinding({
    required this.appId,
    required this.deviceId,
    required this.platform,
  });
  final String appId;
  final String deviceId;
  final String platform;
  Map<String, String> toJson() => {
    'appId': appId,
    'deviceId': deviceId,
    'platform': platform,
  };
}

class LicenseClaims {
  const LicenseClaims({
    required this.licenseId,
    required this.appId,
    required this.deviceId,
    required this.issuedAt,
    required this.expiresAt,
  });
  final String licenseId;
  final String appId;
  final String deviceId;
  final DateTime issuedAt;
  final DateTime expiresAt;
}

abstract interface class LicenseClock {
  DateTime now();
}

class SystemLicenseClock implements LicenseClock {
  const SystemLicenseClock();
  @override
  DateTime now() => DateTime.now().toUtc();
}

class OfflineLicenseValidator {
  OfflineLicenseValidator({required this.publicKey, LicenseClock? clock})
    : clock = clock ?? const SystemLicenseClock();
  final SimplePublicKey publicKey;
  final LicenseClock clock;

  Future<LicenseClaims> validate(
    String token, {
    required DeviceBinding binding,
  }) async {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw const FormatException();
      final signed = utf8.encode('${parts[0]}.${parts[1]}');
      final signature = Signature(_decode(parts[2]), publicKey: publicKey);
      if (!await Ed25519().verify(signed, signature: signature)) {
        throw const FormatException();
      }
      final header =
          jsonDecode(utf8.decode(_decode(parts[0]))) as Map<String, dynamic>;
      final body =
          jsonDecode(utf8.decode(_decode(parts[1]))) as Map<String, dynamic>;
      if (header['alg'] != 'EdDSA' || header['typ'] != 'EVF-LIC') {
        throw const FormatException();
      }
      final claims = LicenseClaims(
        licenseId: body['jti'] as String,
        appId: body['appId'] as String,
        deviceId: body['deviceId'] as String,
        issuedAt: DateTime.fromMillisecondsSinceEpoch(
          (body['iat'] as int) * 1000,
          isUtc: true,
        ),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          (body['exp'] as int) * 1000,
          isUtc: true,
        ),
      );
      final now = clock.now().toUtc();
      if (claims.appId != binding.appId ||
          claims.deviceId != binding.deviceId ||
          !now.isBefore(claims.expiresAt) ||
          claims.issuedAt.isAfter(now.add(const Duration(minutes: 5))) ||
          claims.expiresAt.difference(claims.issuedAt) >
              const Duration(days: 7, minutes: 5)) {
        throw const FormatException();
      }
      return claims;
    } catch (_) {
      throw const FaceSdkException(
        FaceSdkError.licenseInvalid,
        'Licence signature, binding, or validity window is invalid.',
      );
    }
  }

  static List<int> _decode(String value) =>
      base64Url.decode(base64Url.normalize(value));
}

class LicenseActivator {
  LicenseActivator({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  Future<String> activate({
    required Uri endpoint,
    required String activationCode,
    required DeviceBinding binding,
  }) async {
    final response = await _client.post(
      endpoint,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'activationCode': activationCode, ...binding.toJson()}),
    );
    if (response.statusCode != 200) {
      throw const FaceSdkException(
        FaceSdkError.licenseInvalid,
        'Activation was rejected.',
      );
    }
    final token =
        (jsonDecode(response.body) as Map<String, dynamic>)['license']
            as String?;
    if (token == null) {
      throw const FaceSdkException(
        FaceSdkError.licenseInvalid,
        'Activation response was invalid.',
      );
    }
    return token;
  }
}
