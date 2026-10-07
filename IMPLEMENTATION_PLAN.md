# Implementation plan and status

1. **Compatibility audit — complete.** Inspected the read-only Android/Dart source pipeline and captured preprocessing, alignment, thresholds, median, and spoof-latch behavior.
2. **Package boundary — complete.** Created an independent Flutter plugin repository with typed API, model-versioned templates, stable errors, lifecycle methods, and licence gate.
3. **Native engines — implemented.** Android uses ML Kit and TensorFlow Lite; iOS uses Vision and TensorFlowLiteSwift. Both perform single-face/quality gating, five-point alignment, BGR preprocessing, L2 normalization, cosine comparison, and MiniFAS fusion.
4. **Trial licensing — implemented.** Ed25519 compact licences, one-time D1 activation, seven-day expiry, package/bundle and installation binding, offline validation.
5. **Example/tests/docs — implemented.** Runnable capture demo, unit/boundary tests, security/privacy/provenance documents, and release checklist.
6. **Pre-release validation — required.** Device matrix, PAD/matching calibration, provenance clearance, external security review, and release signing remain release gates.
