# Threat model

Assets are biometric images, templates, model files, activation codes, licences, and the signing key. The device OS/secure hardware, app sandbox, native library, Worker, D1, and release pipeline are separate trust boundaries.

- Network interception: activation uses HTTPS and a signed response; offline checks do not trust transport.
- Licence forgery/tampering: Ed25519 signature and exact app/device binding. Trial expiry is signed and checked offline. A lifetime offline licence cannot be remotely revoked after installation, and runtime patching on compromised devices remains possible.
- Replay/presentation: two-model passive PAD, temporal median, spoof latch, framing and pose gates. This does not prove freshness against all replays or masks.
- Template theft: host must envelope-encrypt templates with Keystore/Keychain-protected keys. Embeddings are sensitive biometric data.
- Model delivery/replacement: R2 is private; each activation gets a short-lived one-use grant and unique AES-GCM transport key. The client verifies the plaintext pack hash and native tensor shapes. Protect Worker secrets, R2, CI, and signed artifacts. A licensed user on a compromised device can still extract models; client-side controls cannot prevent this absolutely.
- Data leakage: no biometric networking/logging; stable redacted errors; minimize analytics/crash attachments.
- Denial of service: host should enforce bounded image size; operations are serialized and lifecycle-scoped.

Protection from a fully compromised OS/process, forensic acquisition of an unlocked device, coercion, lookalikes/twins, and guaranteed PAD against unknown attacks are not claimed.
