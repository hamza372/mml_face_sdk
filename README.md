# eVerif Face SDK

Production-oriented Flutter plugin for offline, on-device 1:1 face comparison and passive liveness on Android and iOS. Native code performs face detection, five-landmark alignment, TensorFlow Lite inference, quality gating, and decision state. The licensing service receives only an activation code, app identifier, platform, and a hashed installation binding—never images, video, embeddings, or templates.

> Status: pre-release integration baseline. The bundled thresholds (`0.70` similarity and `0.75` liveness) reproduce the source application behavior. They are **not independently validated operating points**. Calibrate against representative users, devices, capture conditions, and attack media before production.

## Capabilities

- Enrollment/template creation from one encoded image.
- Recognition-only 1:1 comparison.
- Passive liveness plus 1:1 verification using two MiniFAS models and a four-frame median.
- Single-face, minimum-size, pose, landmark, finite-output, and template-version gates.
- Seven-day, app- and device-bound Ed25519 licence verified offline after one-time activation.
- No feature reduction or accuracy weakening for trial users.

## Quick start

```dart
final sdk = EverifFaceSdk(
  publicLicenseKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
);
await sdk.initialize(license: tokenStoredInSecureStorage);
final template = await sdk.createTemplate(enrollmentJpegBytes);
final recognition = await sdk.recognize(encodedImage: probeJpegBytes, template: template);
final verified = await sdk.verify(encodedImage: nextLivenessFrame, template: template);
```

For liveness, submit four consecutive same-session frames/captures. Call `resetLiveness()` when the subject, camera session, or flow changes. The demo uses the system camera picker for portability; a shipping app should integrate a guided native frame stream at a controlled cadence.

See [integration guide](docs/INTEGRATION.md), [API reference](docs/API.md), [threat model](docs/THREAT_MODEL.md), [attack statement](docs/SUPPORTED_ATTACKS.md), [privacy notes](docs/PRIVACY.md), [model inventory](docs/MODELS.md), and [release checklist](docs/RELEASE_CHECKLIST.md).

## Development

```sh
flutter pub get
flutter analyze
flutter test
cd example
flutter run --dart-define=EVERIF_LICENSE_PUBLIC_KEY=BASE64URL_RAW_ED25519_KEY --dart-define=EVERIF_ACTIVATION_URL=http://127.0.0.1:8787/v1/activate
```

The source attendance app is not a dependency and is not modified. The three model files were copied byte-for-byte into `assets/models`; checksums are recorded in `docs/MODELS.md`.
