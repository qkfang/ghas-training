const test = require('node:test');
const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const express = require('express');
const http = require('node:http');

test('backup validates names and passes tar arguments without a shell', async () => {
  let invocation;
  const originalExecFile = childProcess.execFile;
  childProcess.execFile = (command, args, callback) => {
    invocation = { command, args };
    callback(null);
  };
  delete require.cache[require.resolve('../src/routes/integrations')];
  const integrations = require('../src/routes/integrations');
  childProcess.execFile = originalExecFile;

  const app = express();
  app.use('/integrations', integrations);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const url = `http://127.0.0.1:${server.address().port}/integrations/backup`;

  try {
    const unsafeResponse = await fetch(`${url}?name=archive%3Btouch%20/tmp/pwned`, {
      method: 'POST'
    });
    assert.equal(unsafeResponse.status, 400);
    assert.equal(invocation, undefined);

    const safeResponse = await fetch(`${url}?name=nightly_backup`, { method: 'POST' });
    assert.equal(safeResponse.status, 202);
    assert.deepEqual(invocation, {
      command: 'tar',
      args: ['-czf', '/tmp/nightly_backup.tgz', './data']
    });
  } finally {
    await new Promise((resolve, reject) => server.close((err) => (err ? reject(err) : resolve())));
  }
});
