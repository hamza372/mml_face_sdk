# API reference

- `MmlFaceSdk(publicLicenseKey, matchThreshold: 0.70)`: stateful SDK client. The threshold is a compatibility default requiring calibration.
- `activate(endpoint, activationCode)`: one online activation; validates the signed token, downloads the private encrypted model pack, verifies it, and installs it in app-private storage.
- `initialize(license)`: verifies the trial or lifetime licence signature, expiry, app ID, installation binding, and presence of the installed model pack offline.
- `createTemplate(encodedImage)`: quality-gates one face and returns an L2-normalized, model-versioned embedding.
- `createTemplateFromFrame(nv21, width, height, rotationDegrees)`: Android real-time equivalent for a raw NV21 camera frame.
- `recognize(encodedImage, template)`: 1:1 cosine comparison without liveness.
- `recognizeFrame(nv21, width, height, rotationDegrees, template)`: performs recognition directly on an Android NV21 camera frame.
- `verify(encodedImage, template)`: updates passive-liveness state; returns similarity only after the four-frame gate passes.
- `verifyFrame(nv21, width, height, rotationDegrees, template)`: updates passive liveness and recognition directly from an Android NV21 camera frame.
- `resetLiveness()`: clears median and spoof latch for a new attempt.
- `dispose()`: releases detector/interpreters.

`VerificationResult.matched` combines threshold and, when requested, liveness. `FaceSdkException` contains a stable error; messages intentionally omit native details and biometric values.

The frame APIs are currently Android-only and expect `ImageFormatGroup.nv21`. Process one frame at a time and drop incoming frames while an SDK call is in progress.
