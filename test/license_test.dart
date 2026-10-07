import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:mml_face_sdk/mml_face_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

class FixedClock implements LicenseClock {
  FixedClock(this.value);
  final DateTime value;
  @override
  DateTime now() => value;
}

String enc(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

void main() {
  test('validates a lifetime app and device bound licence', () async {
    final algorithm = Ed25519(),
        keys = await algorithm.newKeyPair(),
        pub = await keys.extractPublicKey();
    final now = DateTime.utc(2026, 1, 1);
    final iat = now.millisecondsSinceEpoch ~/ 1000;
    final h = enc({'alg': 'EdDSA', 'typ': 'MML-LIC'}),
        p = enc({
          'jti': 'id',
          'appId': 'com.test',
          'deviceId': 'device',
          'iat': iat,
          'perpetual': true,
        });
    final signed = utf8.encode('$h.$p');
    final sig = await algorithm.sign(signed, keyPair: keys);
    final token = '$h.$p.${base64Url.encode(sig.bytes).replaceAll('=', '')}';
    final claims =
        await OfflineLicenseValidator(
          publicKey: pub,
          clock: FixedClock(now),
        ).validate(
          token,
          binding: const DeviceBinding(
            appId: 'com.test',
            deviceId: 'device',
            platform: 'ios',
          ),
        );
    expect(claims.licenseId, 'id');
    expect(claims.isPerpetual, isTrue);
    expect(claims.expiresAt, isNull);
    expect(
      () => OfflineLicenseValidator(publicKey: pub, clock: FixedClock(now))
          .validate(
            token,
            binding: const DeviceBinding(
              appId: 'other',
              deviceId: 'device',
              platform: 'ios',
            ),
          ),
      throwsA(isA<FaceSdkException>()),
    );
  });
}
