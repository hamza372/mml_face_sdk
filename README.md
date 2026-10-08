# MML Face SDK

Production-oriented Flutter plugin for offline, on-device 1:1 face comparison and passive liveness on Android and iOS. Native code performs face detection, five-landmark alignment, TensorFlow Lite inference, quality gating, and decision state. Model weights are not published with this package: activation installs a privately delivered, per-activation encrypted model pack into app-private storage. The service never receives images, video, embeddings, or templates.

> Status: pre-release integration baseline. The bundled thresholds (`0.75` similarity and `0.75` liveness) are compatibility defaults. They are **not independently validated operating points**. Calibrate against representative users, devices, capture conditions, and attack media before production.

## See it in action

[![MML Face SDK demonstration showing enrollment, replay rejection, and successful live verification](https://raw.githubusercontent.com/hamza372/mml_face_sdk/main/assets/demo/mml-face-sdk-demo.gif)](https://mobilemllabs.com/face-sdk)

**[Watch the complete 36-second demonstration on the MML Face SDK product page](https://mobilemllabs.com/face-sdk)** or [open the full-quality MP4 directly](https://github.com/hamza372/mml_face_sdk/releases/latest/download/mml-face-sdk-demo.mp4).

The complete recording shows local enrollment, successful live verification, rejection of a presentation/replay attempt, and successful verification when the live user returns.

> Demonstration recorded on one Android device under controlled conditions. It is not an independent presentation-attack certification. Production deployments must validate thresholds and attack performance for their supported devices and environments.

## Capabilities

- Enrollment/template creation from one encoded image.
- Recognition-only 1:1 comparison.
- Passive liveness plus 1:1 verification using two MiniFAS models and a four-frame median.
- Single-face, minimum-size, pose, landmark, finite-output, and template-version gates.
- Seven-day evaluation and lifetime Ed25519 licences bound to the customer app and each activated installation, then verified fully offline.
- A reusable customer key activates multiple installations of one Android package or iOS bundle identifier; trial time starts once per app and cannot be reset by reinstalling.

## Try the Android demo

[Download the signed demo APK](https://github.com/hamza372/mml_face_sdk/releases/latest/download/mml-face-sdk-demo.apk). It activates its demo-only licence automatically and is restricted to the demo package identifier. SHA-256: `48660a7700e181d451bca3a1109d78c3caee3f28d21c9d43650de53ebdb17458`.

For a seven-day trial in your own app, [contact Mobile ML Labs on WhatsApp](https://wa.me/923318421757?text=Hi%20Mobile%20ML%20Labs%2C%20I%20want%20to%20evaluate%20MML%20Face%20SDK.%0A%0AName%20%2F%20company%3A%0APlatform%20(Android%20or%20iOS)%3A%0APackage%20name%20%2F%20bundle%20ID%3A%0AApp%20or%20website%20link%3A%0AIntended%20use%3A) with your platform and exact Android package name or iOS bundle identifier.

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

For liveness, submit four consecutive same-session frames. Call `resetLiveness()` when the subject, camera session, or flow changes. The demo keeps an embedded camera preview open and processes Android NV21 frames directly as soon as the native engine is available.

See [integration guide](doc/INTEGRATION.md), [API reference](doc/API.md), [threat model](doc/THREAT_MODEL.md), [attack statement](doc/SUPPORTED_ATTACKS.md), [privacy notes](doc/PRIVACY.md), [model inventory](doc/MODELS.md), and [release checklist](doc/RELEASE_CHECKLIST.md).

## Development

```sh
flutter pub get
flutter analyze
flutter test
cd example
flutter run --dart-define=MML_LICENSE_PUBLIC_KEY=vJZyhTYJIS4JWop8tIlY1Juyzpyv434M_BUQhgHzgDY --dart-define=MML_ACTIVATION_URL=https://mml-face-license.hamzaasif19974-69b.workers.dev/v1/activate
```

The source attendance app is not a dependency and is not modified. This public package contains no biometric model weights. Commercial activation and a private model pack are required for inference.

Support: [hamzaasif19974@gmail.com](mailto:hamzaasif19974@gmail.com)

Product page: [mobilemllabs.com/face-sdk](https://mobilemllabs.com/face-sdk) · [Source and issues](https://github.com/hamza372/mml_face_sdk)
