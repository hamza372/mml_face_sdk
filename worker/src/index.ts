interface Env { LICENSE_DB: D1Database; LICENSE_PRIVATE_JWK: string; }
type RequestBody = { activationCode?: string; appId?: string; deviceId?: string; platform?: string };

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {status, headers: {'content-type': 'application/json', 'cache-control': 'no-store'}});
const b64url = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
const encode = (value: unknown) => b64url(new TextEncoder().encode(JSON.stringify(value)));
const hash = async (value: string) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)))).map(v => v.toString(16).padStart(2, '0')).join('');

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== 'POST' || new URL(request.url).pathname !== '/v1/activate') return json({error: 'not_found'}, 404);
    let body: RequestBody; try { body = await request.json<RequestBody>(); } catch { return json({error: 'invalid_request'}, 400); }
    if (!body.activationCode || body.activationCode.length > 256 || !body.appId || body.appId.length > 255 || !body.deviceId || body.deviceId.length > 128 || !['android', 'ios'].includes(body.platform ?? '')) return json({error: 'invalid_request'}, 400);
    let key: CryptoKey; try { key = await crypto.subtle.importKey('jwk', JSON.parse(env.LICENSE_PRIVATE_JWK), {name: 'Ed25519'}, false, ['sign']); } catch { return json({error: 'server_configuration'}, 503); }
    const codeHash = await hash(body.activationCode);
    const row = await env.LICENSE_DB.prepare('SELECT redeemed_at FROM activation_codes WHERE code_hash = ?').bind(codeHash).first<{redeemed_at: number | null}>();
    if (!row || row.redeemed_at !== null) return json({error: 'activation_rejected'}, 403);
    const now = Math.floor(Date.now() / 1000), licenseId = crypto.randomUUID();
    const update = await env.LICENSE_DB.prepare('UPDATE activation_codes SET redeemed_at=?, license_id=?, app_id=?, device_id=? WHERE code_hash=? AND redeemed_at IS NULL').bind(now, licenseId, body.appId, body.deviceId, codeHash).run();
    if (update.meta.changes !== 1) return json({error: 'activation_rejected'}, 403);
    const header = encode({alg: 'EdDSA', typ: 'EVF-LIC'}), payload = encode({jti: licenseId, appId: body.appId, deviceId: body.deviceId, platform: body.platform, iat: now, exp: now + 7 * 24 * 60 * 60});
    const signature = await crypto.subtle.sign('Ed25519', key, new TextEncoder().encode(`${header}.${payload}`));
    return json({license: `${header}.${payload}.${b64url(new Uint8Array(signature))}`});
  }
};
