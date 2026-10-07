const pair = await crypto.subtle.generateKey({name: 'Ed25519'}, true, ['sign', 'verify']);
console.log('Private JWK (store with wrangler secret put LICENSE_PRIVATE_JWK):');
console.log(JSON.stringify(await crypto.subtle.exportKey('jwk', pair.privateKey)));
console.log('Public raw key (base64url, embed in app):');
const raw = new Uint8Array(await crypto.subtle.exportKey('raw', pair.publicKey));
console.log(Buffer.from(raw).toString('base64url'));
