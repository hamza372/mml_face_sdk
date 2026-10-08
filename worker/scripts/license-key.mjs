import {createHash, randomBytes} from 'node:crypto';
import {spawnSync} from 'node:child_process';

const [command, ...rawArgs] = process.argv.slice(2);
const args = Object.fromEntries(rawArgs.reduce((pairs, value, index, values) => {
  if (value.startsWith('--')) pairs.push([value.slice(2), values[index + 1]]);
  return pairs;
}, []));

function fail(message) {
  console.error(message);
  process.exit(1);
}

function sqlText(value) {
  return `'${value.replaceAll("'", "''")}'`;
}

function d1(sql) {
  const result = spawnSync('npx', ['wrangler', 'd1', 'execute', 'LICENSE_DB', '--remote', '--command', sql], {encoding: 'utf8'});
  if (result.status !== 0) fail(result.stderr || result.stdout || 'D1 command failed.');
  return result.stdout;
}

if (command === 'create') {
  const appId = args['app-id'];
  const platform = args.platform;
  const type = args.type;
  const days = Number(args.days ?? '7');
  const label = args.label ?? `${type} for ${appId}`;
  if (!appId || !/^[A-Za-z0-9][A-Za-z0-9._-]{2,254}$/.test(appId)) fail('Provide a valid --app-id.');
  if (!['android', 'ios'].includes(platform)) fail('Provide --platform android or --platform ios.');
  if (!['trial', 'lifetime'].includes(type)) fail('Provide --type trial or --type lifetime.');
  if (type === 'trial' && (!Number.isInteger(days) || days < 1 || days > 7)) fail('Trial --days must be between 1 and 7.');
  const code = `MML-${type === 'trial' ? 'TRIAL' : 'LIFETIME'}-${randomBytes(24).toString('base64url')}`;
  const codeHash = createHash('sha256').update(code).digest('hex');
  const now = Math.floor(Date.now() / 1000);
  d1(`INSERT INTO activation_codes(code_hash, allowed_app_id, allowed_platform, license_type, trial_days, label, created_at) VALUES (${sqlText(codeHash)}, ${sqlText(appId)}, ${sqlText(platform)}, ${sqlText(type)}, ${type === 'trial' ? days : 'NULL'}, ${sqlText(label)}, ${now})`);
  console.log(JSON.stringify({key: code, appId, platform, type, days: type === 'trial' ? days : null, note: 'Save and send this key now. Only its SHA-256 hash is stored.'}, null, 2));
} else if (command === 'list') {
  process.stdout.write(d1("SELECT substr(code_hash, 1, 12) AS key_id, label, allowed_app_id, allowed_platform, license_type, trial_days, trial_started_at, enabled, created_at FROM activation_codes ORDER BY created_at DESC"));
} else if (command === 'disable') {
  const keyId = args['key-id'];
  if (!keyId || !/^[a-f0-9]{8,64}$/.test(keyId)) fail('Provide the hexadecimal --key-id shown by the list command.');
  process.stdout.write(d1(`UPDATE activation_codes SET enabled=0 WHERE code_hash LIKE ${sqlText(`${keyId}%`)}`));
} else {
  fail('Usage: node scripts/license-key.mjs create --app-id com.example.app --platform android --type trial --days 7 | list | disable --key-id abc12345');
}
