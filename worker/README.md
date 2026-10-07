# Licence Worker

1. `npm install && node scripts/generate-key.mjs`.
2. Embed the printed public raw base64url key in the host app. Store the private JWK only with `npx wrangler secret put LICENSE_PRIVATE_JWK`.
3. `npx wrangler d1 create everif-face-license`, copy its ID into `wrangler.toml`, then run `npm run db:local` or `npm run db:remote`.
4. Insert activation codes by SHA-256 hash only: `INSERT INTO activation_codes(code_hash) VALUES ('...');`.
5. Run `npm run dev` or `npm run deploy`.

`POST /v1/activate` accepts only `activationCode`, `appId`, `deviceId`, and `platform`. D1 atomically redeems an unused code and the Worker returns a seven-day Ed25519 licence. Never add biometric fields or request logging containing secrets. Add Cloudflare rate limits/WAF before production.
