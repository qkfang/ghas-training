const SAFE_FILE = /^[a-z0-9-]{1,64}\.pdf$/;

function assertSafeFileName(name) {
  if (typeof name !== 'string' || !SAFE_FILE.test(name)) {
    const err = new Error('Invalid file name');
    err.status = 400;
    throw err;
  }
}

module.exports = { assertSafeFileName };
