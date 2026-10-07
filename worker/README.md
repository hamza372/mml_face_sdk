# Licence Worker

1. `npm install && node scripts/generate-key.mjs`.
2. Embed the printed public raw base64url key in the host app. Store the private JWK only with `npx wrangler secret put LICENSE_PRIVATE_JWK`.
3. `npx wrangler d1 create mml-face-license`, copy its ID into `wrangler.toml`, then run `npm run db:local` or `npm run db:remote`.
4. Create the private bucket: `npx wrangler r2 bucket create mml-face-models`.
5. Build the ZIP with `npm run build:model-pack`. Copy its printed SHA-256 into `wrangler.toml` as `MODEL_PACK_SHA256`.
6. Upload it privately: `npx wrangler r2 object put mml-face-models/model-pack-v1.zip --file=../work/model_pack/model-pack-v1.zip`.
7. Insert customer app keys by SHA-256 hash only: `INSERT INTO activation_codes(code_hash) VALUES ('...');`. A key binds permanently to the first app identifier that activates it and can be reused by installations of that app.
8. Run `npm run dev` or `npm run deploy`.

`POST /v1/activate` accepts only `activationCode`, `appId`, `deviceId`, and `platform`. It returns a lifetime, device-bound Ed25519 licence and a 15-minute, one-use model grant. The same customer key can activate multiple devices only when the app identifier matches its permanent binding. `GET /v1/model-pack/{grant}` reads the private R2 object and encrypts it with a unique AES-256-GCM key returned only in the activation response. The SDK verifies and installs it, then operates offline. Issued lifetime licences cannot be remotely revoked. Never add biometric fields or request logging containing secrets. Add Cloudflare rate limits/WAF before production.
