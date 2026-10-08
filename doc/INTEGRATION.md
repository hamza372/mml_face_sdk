# Integration guide

## Platform requirements

- Android API 24+, camera permission in the host manifest, Java 17 toolchain.
- iOS 13+, `NSCameraUsageDescription`, CocoaPods, and a physical device for camera/PAD testing.

The encoded-image API accepts JPEG/PNG bytes. Android also provides raw NV21 frame methods for instant camera-stream processing. Decode, face detection, landmarks, preprocessing, and inference stay native. Do not resize, normalize, or crop before passing bytes.

## Licence bootstrap

Embed only the raw 32-byte Ed25519 public key. Store the returned licence in Keychain/Keystore-backed secure storage. Activation is once per installation: the Worker returns a trial or lifetime signed licence plus a one-use, 15-minute model-pack grant. Trial keys are pre-bound to an app and platform; their shared seven-day period begins on first activation and is not reset by another installation. Lifetime keys can activate additional installations of the same app. The SDK downloads the pack, decrypts it in memory, verifies its SHA-256 digest and native tensor shapes, then installs it in app-private, backup-excluded storage. Subsequent launches call `initialize(license:)` without network. Never embed signing keys, model-pack keys, customer licence keys, or the activation database in a distributed customer app. The public demo is the sole exception: it receives a dedicated key restricted to its fixed demo package identifier at build time.

## Template storage

`FaceTemplate.toJson()` is serialization, not encryption. Encrypt it with a random data-encryption key protected by iOS Keychain/Android Keystore; use authenticated encryption, strict file permissions, backup exclusion, deletion on sign-out/account deletion, and key rotation. Do not log templates or scores tied to identities.

## Capture flow

Use front camera, even lighting, neutral frontal pose, one face, adequate apparent size, and four consecutive liveness samples. Keep a single SDK instance for the session. Reset on pause, timeout, camera switch, or subject change; dispose when the owning screen/service ends. Serialize calls—concurrent inference is unsupported.

For real-time Android verification, create the camera with `ImageFormatGroup.nv21`, call `startImageStream`, pass the raw NV21 bytes and camera rotation to `recognizeFrame` or `verifyFrame`, and ignore new frames while one is being processed. Recognition can complete on the first matching frame. Passive liveness intentionally requires four accepted frames before matching.

Treat face/quality errors as retryable guidance. A spoof latch requires ending or explicitly resetting the attempt. Do not expose raw scores as proof of identity.
