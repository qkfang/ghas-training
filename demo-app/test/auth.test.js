const test = require('node:test');
const assert = require('node:assert');
const jwt = require('jsonwebtoken');

// DEMO ALERTS ("used in tests" candidates): hard-coded key and fake API key in test code only.
const TEST_SIGNING_KEY = 'unit-test-only-signing-key';
const FAKE_ACME_KEY = 'acme_test_Zz9Yy8Xx7Ww6Vv5Uu4Tt3Ss2';

test('tokens round-trip with the test key', () => {
  const token = jwt.sign({ sub: 'bob' }, TEST_SIGNING_KEY);
  assert.strictEqual(jwt.verify(token, TEST_SIGNING_KEY).sub, 'bob');
  assert.ok(FAKE_ACME_KEY.startsWith('acme_test_'));
});
