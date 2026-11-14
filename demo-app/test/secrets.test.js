const test = require('node:test');
const assert = require('node:assert');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const appRoot = path.resolve(__dirname, '..');

function runNode(code, env) {
  return spawnSync(process.execPath, ['-e', code], {
    cwd: appRoot,
    env: { ...process.env, ...env },
    encoding: 'utf8',
  });
}

const requiredSecrets = [
  ['./src/config/settings', 'ACME_API_KEY'],
  ['./src/config/partners', 'ACME_LOGISTICS_API_KEY'],
  ['./scripts/backfill', 'ACME_API_KEY'],
  ['./src/auth', 'JWT_SECRET'],
];

for (const [modulePath, variable] of requiredSecrets) {
  test(`${modulePath} fails fast without ${variable}`, () => {
    const result = runNode(`require(${JSON.stringify(modulePath)})`, { [variable]: '' });

    assert.notStrictEqual(result.status, 0);
    assert.match(result.stderr, new RegExp(`${variable} environment variable is required`));
  });
}

test('configuration modules use their environment-provided keys', () => {
  const settings = runNode(
    `process.stdout.write(require('./src/config/settings').acmePaymentsApiKey)`,
    { ACME_API_KEY: 'configured-payments-key' },
  );
  const partners = runNode(
    `process.stdout.write(require('./src/config/partners').partners[0].apiKey)`,
    { ACME_LOGISTICS_API_KEY: 'configured-logistics-key' },
  );

  assert.strictEqual(settings.status, 0, settings.stderr);
  assert.strictEqual(settings.stdout, 'configured-payments-key');
  assert.strictEqual(partners.status, 0, partners.stderr);
  assert.strictEqual(partners.stdout, 'configured-logistics-key');
});

test('backfill uses the configured key without logging it', () => {
  const result = runNode("require('./scripts/backfill')", { ACME_API_KEY: 'configured-backfill-key' });

  assert.strictEqual(result.status, 0, result.stderr);
  assert.match(result.stdout, /Backfilling orders with configured ACME key/);
  assert.doesNotMatch(result.stdout, /configured-backfill-key/);
});

test('authentication module loads with a configured JWT secret', () => {
  const result = runNode("require('./src/auth')", { JWT_SECRET: 'configured-jwt-secret' });

  assert.strictEqual(result.status, 0, result.stderr);
});
