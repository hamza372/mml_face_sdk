import {spawnSync} from 'node:child_process';
import {createHash, randomBytes} from 'node:crypto';

const workerUrl = process.env.MML_WORKER_URL;
if (!workerUrl) throw new Error('Set MML_WORKER_URL to the deployed Worker URL.');

const publicKeyBase64 = 'vJZyhTYJIS4JWop8tIlY1Juyzpyv434M_BUQhgHzgDY';
const expectedPackHash = 'd2387b95b294fcbb0035be383a6a301065c8211c8ece9bcc7ecbd780f3be3e50';
const activationCode = `MML-TEST-${randomBytes(24).toString('base64url')}`;
const codeHash = sha256(activationCode);
const grantHashes = [];

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function decodeBase64Url(value) {
  return Buffer.from(value, 'base64url');
}

function executeSql(command) {
  const result = spawnSync(
    'npx',
    ['wrangler', 'd1', 'execute', 'LICENSE_DB', '--remote', '--command', command],
    {encoding: 'utf8'},
  );
  if (result.status !== 0) {
    throw new Error(result.stderr || result.stdout || 'D1 command failed.');
  }
}

async function activate(appId, deviceId) {
  return fetch(`${workerUrl}/v1/activate`, {
    method: 'POST',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify({activationCode, appId, deviceId, platform: 'android'}),
  });
}

async function assertLicense(token, appId, deviceId) {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('Malformed licence token.');
  const header = JSON.parse(decodeBase64Url(parts[0]));
  const payload = JSON.parse(decodeBase64Url(parts[1]));
  if (header.alg !== 'EdDSA' || header.typ !== 'MML-LIC') {
    throw new Error('Unexpected licence header.');
  }
  if (payload.appId !== appId || payload.deviceId !== deviceId || payload.perpetual !== true) {
    throw new Error('Unexpected lifetime licence claims.');
  }
  const publicKey = await crypto.subtle.importKey(
    'raw',
    decodeBase64Url(publicKeyBase64),
    {name: 'Ed25519'},
    false,
    ['verify'],
  );
  const valid = await crypto.subtle.verify(
    'Ed25519',
    publicKey,
    decodeBase64Url(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!valid) throw new Error('Licence signature verification failed.');
  return payload.jti;
}

async function downloadAndVerifyModelPack(modelPack) {
  const grant = new URL(modelPack.url).pathname.split('/').pop();
  grantHashes.push(sha256(grant));
  const response = await fetch(modelPack.url);
  if (response.status !== 200) throw new Error(`Model download returned ${response.status}.`);
  const sealed = new Uint8Array(await response.arrayBuffer());
  const key = await crypto.subtle.importKey(
    'raw',
    decodeBase64Url(modelPack.key),
    {name: 'AES-GCM'},
    false,
    ['decrypt'],
  );
  const clear = await crypto.subtle.decrypt(
    {name: 'AES-GCM', iv: sealed.slice(0, 12)},
    key,
    sealed.slice(12),
  );
  if (sha256(Buffer.from(clear)) !== expectedPackHash || modelPack.sha256 !== expectedPackHash) {
    throw new Error('Model-pack checksum verification failed.');
  }
  const replay = await fetch(modelPack.url);
  if (replay.status !== 403) throw new Error('One-time model grant was reusable.');
}

try {
  executeSql(`INSERT INTO activation_codes(code_hash) VALUES ('${codeHash}')`);

  const first = await activate('com.mobilemllabs.smoketest', 'device-one');
  if (first.status !== 200) {
    throw new Error(`Initial activation returned ${first.status}: ${await first.text()}`);
  }
  const firstBody = await first.json();
  await assertLicense(firstBody.license, 'com.mobilemllabs.smoketest', 'device-one');
  await downloadAndVerifyModelPack(firstBody.modelPack);

  const second = await activate('com.mobilemllabs.smoketest', 'device-two');
  if (second.status !== 200) throw new Error(`Same-app activation returned ${second.status}.`);
  const secondBody = await second.json();
  await assertLicense(secondBody.license, 'com.mobilemllabs.smoketest', 'device-two');
  grantHashes.push(sha256(new URL(secondBody.modelPack.url).pathname.split('/').pop()));

  const wrongApp = await activate('com.example.other', 'device-three');
  if (wrongApp.status !== 403) throw new Error('The app-bound key activated a different app.');

  console.log('Remote smoke test passed: signature, lifetime claims, app binding, reusable app key, encrypted model download, checksum, and one-time grant.');
} finally {
  const grants = grantHashes.length
    ? `DELETE FROM model_grants WHERE grant_hash IN (${grantHashes.map((value) => `'${value}'`).join(',')});`
    : '';
  executeSql(`${grants} DELETE FROM license_activations WHERE code_hash='${codeHash}'; DELETE FROM activation_codes WHERE code_hash='${codeHash}';`);
}
