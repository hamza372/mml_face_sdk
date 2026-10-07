# Integration guide

## Platform requirements

- Android API 24+, camera permission in the host manifest, Java 17 toolchain.
- iOS 13+, `NSCameraUsageDescription`, CocoaPods, and a physical device for camera/PAD testing.

The API accepts JPEG/PNG bytes. Decode, face detection, landmarks, preprocessing, and inference stay native. Do not resize, normalize, or crop before passing bytes.

## Licence bootstrap

Embed only the raw 32-byte Ed25519 public key. Store the returned licence in Keychain/Keystore-backed secure storage. Activation is once per installation; subsequent launches call `initialize(license:)` without network. A reinstall can change the installation binding and requires a new code. Never embed the private key or activation-code database.

## Template storage

`FaceTemplate.toJson()` is serialization, not encryption. Encrypt it with a random data-encryption key protected by iOS Keychain/Android Keystore; use authenticated encryption, strict file permissions, backup exclusion, deletion on sign-out/account deletion, and key rotation. Do not log templates or scores tied to identities.

## Capture flow

Use front camera, even lighting, neutral frontal pose, one face, adequate apparent size, and four consecutive liveness samples. Keep a single SDK instance for the session. Reset on pause, timeout, camera switch, or subject change; dispose when the owning screen/service ends. Serialize calls—concurrent inference is unsupported.

Treat face/quality errors as retryable guidance. A spoof latch requires ending or explicitly resetting the attempt. Do not expose raw scores as proof of identity.
