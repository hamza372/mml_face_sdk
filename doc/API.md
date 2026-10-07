# API reference

- `MmlFaceSdk(publicLicenseKey, matchThreshold: 0.70)`: stateful SDK client. The threshold is a compatibility default requiring calibration.
- `activate(endpoint, activationCode)`: one online activation; validates the signed token, downloads the private encrypted model pack, verifies it, and installs it in app-private storage.
- `initialize(license)`: verifies signature, expiry, seven-day maximum window, app ID, installation binding, and the presence of the installed model pack offline.
- `createTemplate(encodedImage)`: quality-gates one face and returns an L2-normalized, model-versioned embedding.
- `recognize(encodedImage, template)`: 1:1 cosine comparison without liveness.
- `verify(encodedImage, template)`: updates passive-liveness state; returns similarity only after the four-frame gate passes.
- `resetLiveness()`: clears median and spoof latch for a new attempt.
- `dispose()`: releases detector/interpreters.

`VerificationResult.matched` combines threshold and, when requested, liveness. `FaceSdkException` contains a stable error; messages intentionally omit native details and biometric values.
