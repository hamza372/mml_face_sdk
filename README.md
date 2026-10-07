# MML Face SDK

Production-oriented Flutter plugin for offline, on-device 1:1 face comparison and passive liveness on Android and iOS. Native code performs face detection, five-landmark alignment, TensorFlow Lite inference, quality gating, and decision state. Model weights are not published with this package: activation installs a privately delivered, per-activation encrypted model pack into app-private storage. The service never receives images, video, embeddings, or templates.

> Status: pre-release integration baseline. The bundled thresholds (`0.70` similarity and `0.75` liveness) reproduce the source application behavior. They are **not independently validated operating points**. Calibrate against representative users, devices, capture conditions, and attack media before production.

## Capabilities

- Enrollment/template creation from one encoded image.
- Recognition-only 1:1 comparison.
- Passive liveness plus 1:1 verification using two MiniFAS models and a four-frame median.
- Single-face, minimum-size, pose, landmark, finite-output, and template-version gates.
- Seven-day, app- and device-bound Ed25519 licence verified offline after one-time activation and model-pack installation.
- No feature reduction or accuracy weakening for trial users.

## Quick start

```dart
import 'package:mml_face_sdk/mml_face_sdk.dart';

final sdk = MmlFaceSdk(
  publicLicenseKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
);
await sdk.initialize(license: tokenStoredInSecureStorage);
final template = await sdk.createTemplate(enrollmentJpegBytes);
final recognition = await sdk.recognize(encodedImage: probeJpegBytes, template: template);
final verified = await sdk.verify(encodedImage: nextLivenessFrame, template: template);
```

For liveness, submit four consecutive same-session frames/captures. Call `resetLiveness()` when the subject, camera session, or flow changes. The demo uses the system camera picker for portability; a shipping app should integrate a guided native frame stream at a controlled cadence.

See [integration guide](doc/INTEGRATION.md), [API reference](doc/API.md), [threat model](doc/THREAT_MODEL.md), [attack statement](doc/SUPPORTED_ATTACKS.md), [privacy notes](doc/PRIVACY.md), [model inventory](doc/MODELS.md), and [release checklist](doc/RELEASE_CHECKLIST.md).

## Development

```sh
flutter pub get
flutter analyze
flutter test
cd example
flutter run --dart-define=MML_LICENSE_PUBLIC_KEY=BASE64URL_RAW_ED25519_KEY --dart-define=MML_ACTIVATION_URL=http://127.0.0.1:8787/v1/activate
```

The source attendance app is not a dependency and is not modified. This public package contains no biometric model weights. Commercial activation and a private model pack are required for inference.

Support: [hamzaasif19974@gmail.com](mailto:hamzaasif19974@gmail.com)

Website: [mobilemllabs.com](https://mobilemllabs.com/) · [Source and issues](https://github.com/hamza372/mml_face_sdk)
