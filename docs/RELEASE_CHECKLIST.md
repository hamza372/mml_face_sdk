# Release checklist

- [ ] Establish commercial redistribution rights and provenance for all exact model binaries.
- [ ] Calibrate threshold; report matching error rates by device and relevant cohorts.
- [ ] Validate PAD; report APCER/BPCER and document limitations.
- [ ] Run Android/iOS physical-device, lifecycle, memory, thermal, orientation, and concurrency tests.
- [ ] Add guided native streaming capture or validate the host capture integration.
- [ ] Encrypt templates with hardware-backed keys; verify deletion, backup exclusion, and rotation.
- [ ] Complete privacy/legal/DPIA review and user consent/retention UX.
- [ ] External security review of native parsing, licence validation, Worker/D1, CI, and supply chain.
- [ ] Pin dependencies, generate SBOM, scan, and verify model checksums in CI.
- [ ] Provision production Ed25519 key in Workers secret storage/HSM process; test rotation.
- [ ] Rate-limit/WAF activation and monitor only non-biometric metadata.
- [ ] Sign release artifacts, archive build evidence, changelog, and rollback package.
