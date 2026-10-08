# Licence Worker

1. `npm install && node scripts/generate-key.mjs`.
2. Embed the printed public raw base64url key in the host app. Store the private JWK only with `npx wrangler secret put LICENSE_PRIVATE_JWK`.
3. `npx wrangler d1 create mml-face-license`, copy its ID into `wrangler.toml`, then run `npm run db:local` or `npm run db:remote`.
4. Create the private bucket: `npx wrangler r2 bucket create mml-face-models`.
5. Build the ZIP with `npm run build:model-pack`. Copy its printed SHA-256 into `wrangler.toml` as `MODEL_PACK_SHA256`.
6. Upload it privately: `npx wrangler r2 object put mml-face-models/model-pack-v1.zip --file=../work/model_pack/model-pack-v1.zip`.
7. Create keys with the private CLI. The clear key is printed once; only its SHA-256 hash is stored:
   - Trial: `npm run key -- create --app-id com.customer.app --platform android --type trial --days 7 --label "Customer trial"`
   - Lifetime: `npm run key -- create --app-id com.customer.app --platform android --type lifetime --label "Customer production"`
   - List: `npm run key -- list`
   - Disable future activations: `npm run key -- disable --key-id HASH_PREFIX`
8. Run `npm run dev` or `npm run deploy`.

Production public licence key (base64url): `vJZyhTYJIS4JWop8tIlY1Juyzpyv434M_BUQhgHzgDY`. Embed this public key in the distributed SDK/app; the corresponding private key exists only in Cloudflare Worker secret storage.

`POST /v1/activate` accepts only `activationCode`, `appId`, `deviceId`, and `platform`. It returns a device-bound Ed25519 licence and a 15-minute, one-use model grant. Trial keys are pre-bound to one app/platform and share a seven-day expiration beginning at the first activation, so reinstalling does not restart the trial. Lifetime keys activate multiple devices only for their app/platform binding. `GET /v1/model-pack/{grant}` reads the private R2 object and encrypts it with a unique AES-256-GCM key returned only in the activation response. The SDK verifies and installs it, then operates offline. Disabling a key stops future activations but cannot revoke lifetime licences already installed. Never add biometric fields or request logging containing secrets. Add Cloudflare rate limits/WAF before production.
