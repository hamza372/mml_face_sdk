interface Env {
  LICENSE_DB: D1Database;
  MODEL_BUCKET: R2Bucket;
  LICENSE_PRIVATE_JWK: string;
  MODEL_PACK_OBJECT: string;
  MODEL_PACK_VERSION: string;
  MODEL_PACK_SHA256: string;
}
type RequestBody = { activationCode?: string; appId?: string; deviceId?: string; platform?: string };

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {status, headers: {'content-type': 'application/json', 'cache-control': 'no-store'}});
const b64url = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
const encode = (value: unknown) => b64url(new TextEncoder().encode(JSON.stringify(value)));
const hash = async (value: string) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)))).map(v => v.toString(16).padStart(2, '0')).join('');
const randomToken = (length: number) => { const value = new Uint8Array(length); crypto.getRandomValues(value); return b64url(value); };
const decode64 = (value: string) => Uint8Array.from(atob(value.replaceAll('-', '+').replaceAll('_', '/').padEnd(Math.ceil(value.length / 4) * 4, '=')), c => c.charCodeAt(0));

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname.startsWith('/v1/model-pack/')) return downloadPack(url.pathname.split('/').pop() ?? '', env);
    if (request.method !== 'POST' || url.pathname !== '/v1/activate') return json({error: 'not_found'}, 404);
    let body: RequestBody; try { body = await request.json<RequestBody>(); } catch { return json({error: 'invalid_request'}, 400); }
    if (!body.activationCode || body.activationCode.length > 256 || !body.appId || body.appId.length > 255 || !body.deviceId || body.deviceId.length > 128 || !['android', 'ios'].includes(body.platform ?? '')) return json({error: 'invalid_request'}, 400);
    let key: CryptoKey;
    try {
      const signingJwk = JSON.parse(env.LICENSE_PRIVATE_JWK) as JsonWebKey;
      delete signingJwk.alg;
      key = await crypto.subtle.importKey('jwk', signingJwk, {name: 'Ed25519'}, false, ['sign']);
    } catch (error) {
      console.error('Licence signing key import failed.', error);
      return json({error: 'server_configuration'}, 503);
    }
    if (!/^[a-f0-9]{64}$/.test(env.MODEL_PACK_SHA256) || !await env.MODEL_BUCKET.head(env.MODEL_PACK_OBJECT)) return json({error: 'model_pack_unavailable'}, 503);
    const codeHash = await hash(body.activationCode);
    const row = await env.LICENSE_DB.prepare('SELECT allowed_app_id, enabled FROM activation_codes WHERE code_hash = ?').bind(codeHash).first<{allowed_app_id: string | null; enabled: number}>();
    if (!row || row.enabled !== 1 || (row.allowed_app_id !== null && row.allowed_app_id !== body.appId)) return json({error: 'activation_rejected'}, 403);
    const now = Math.floor(Date.now() / 1000), licenseId = crypto.randomUUID(), grant = randomToken(32), modelKey = randomToken(32);
    const binding = await env.LICENSE_DB.prepare('UPDATE activation_codes SET allowed_app_id=COALESCE(allowed_app_id, ?), redeemed_at=COALESCE(redeemed_at, ?), license_id=?, app_id=?, device_id=? WHERE code_hash=? AND enabled=1 AND (allowed_app_id IS NULL OR allowed_app_id=?)').bind(body.appId, now, licenseId, body.appId, body.deviceId, codeHash, body.appId).run();
    if (binding.meta.changes !== 1) return json({error: 'activation_rejected'}, 403);
    await env.LICENSE_DB.batch([
      env.LICENSE_DB.prepare('INSERT INTO license_activations(license_id, code_hash, app_id, device_id, platform, activated_at) VALUES(?, ?, ?, ?, ?, ?)').bind(licenseId, codeHash, body.appId, body.deviceId, body.platform, now),
      env.LICENSE_DB.prepare('INSERT INTO model_grants(grant_hash, model_key, expires_at) VALUES(?, ?, ?)').bind(await hash(grant), modelKey, now + 15 * 60),
    ]);
    const header = encode({alg: 'EdDSA', typ: 'MML-LIC'}), payload = encode({jti: licenseId, appId: body.appId, deviceId: body.deviceId, platform: body.platform, iat: now, perpetual: true});
    const signature = await crypto.subtle.sign('Ed25519', key, new TextEncoder().encode(`${header}.${payload}`));
    return json({
      license: `${header}.${payload}.${b64url(new Uint8Array(signature))}`,
      modelPack: {version: env.MODEL_PACK_VERSION, url: `${url.origin}/v1/model-pack/${grant}`, key: modelKey, sha256: env.MODEL_PACK_SHA256},
    });
  }
};

async function downloadPack(grant: string, env: Env): Promise<Response> {
  if (!/^[A-Za-z0-9_-]{40,64}$/.test(grant)) return json({error: 'invalid_grant'}, 403);
  const now = Math.floor(Date.now() / 1000), grantHash = await hash(grant);
  const row = await env.LICENSE_DB.prepare('SELECT model_key, expires_at, redeemed_at FROM model_grants WHERE grant_hash=?').bind(grantHash).first<{model_key: string; expires_at: number; redeemed_at: number | null}>();
  if (!row || row.redeemed_at !== null || row.expires_at < now) return json({error: 'invalid_grant'}, 403);
  const object = await env.MODEL_BUCKET.get(env.MODEL_PACK_OBJECT);
  if (!object) return json({error: 'model_pack_unavailable'}, 503);
  const aes = await crypto.subtle.importKey('raw', decode64(row.model_key), {name: 'AES-GCM'}, false, ['encrypt']);
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = new Uint8Array(await crypto.subtle.encrypt({name: 'AES-GCM', iv: nonce}, aes, await object.arrayBuffer()));
  const redeemed = await env.LICENSE_DB.prepare('UPDATE model_grants SET redeemed_at=? WHERE grant_hash=? AND redeemed_at IS NULL').bind(now, grantHash).run();
  if (redeemed.meta.changes !== 1) return json({error: 'invalid_grant'}, 403);
  const response = new Uint8Array(nonce.length + encrypted.length); response.set(nonce); response.set(encrypted, nonce.length);
  return new Response(response, {headers: {'content-type': 'application/octet-stream', 'cache-control': 'no-store', 'content-length': String(response.length)}});
}
