# Privacy notes

All detection, alignment, liveness, embedding, and matching run on-device. Activation sends only activation code, Android package name or iOS bundle ID, platform, and a hashed installation identifier. It must never receive images, video, landmarks, embeddings, templates, names, or match results.

Obtain informed consent and provide retention/deletion controls. Define a lawful basis and biometric-data policy. Keep images in memory only as long as needed, avoid gallery/cloud backups, encrypt templates, redact logs/crashes, and support account deletion. The SDK does not by itself establish compliance with GDPR, CCPA/CPRA, BIPA, or local biometric laws; obtain jurisdiction-specific legal review.
