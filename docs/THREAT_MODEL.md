# Threat model

Assets are biometric images, templates, model files, activation codes, licences, and the signing key. The device OS/secure hardware, app sandbox, native library, Worker, D1, and release pipeline are separate trust boundaries.

- Network interception: activation uses HTTPS and a signed response; offline checks do not trust transport.
- Licence forgery/tampering: Ed25519 signature, bounded validity, exact app/device binding. Runtime patching on compromised devices remains possible.
- Replay/presentation: two-model passive PAD, temporal median, spoof latch, framing and pose gates. This does not prove freshness against all replays or masks.
- Template theft: host must envelope-encrypt templates with Keystore/Keychain-protected keys. Embeddings are sensitive biometric data.
- Model replacement: verify recorded release checksums; protect CI and signed artifacts.
- Data leakage: no biometric networking/logging; stable redacted errors; minimize analytics/crash attachments.
- Denial of service: host should enforce bounded image size; operations are serialized and lifecycle-scoped.

Protection from a fully compromised OS/process, forensic acquisition of an unlocked device, coercion, lookalikes/twins, and guaranteed PAD against unknown attacks are not claimed.
