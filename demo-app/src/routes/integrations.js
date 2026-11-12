const express = require('express');
const https = require('https');
const { execFile } = require('child_process');

// Owner: team-platform. Session 2/3 demo content.
const router = express.Router();

// DEMO ALERT (true positive, critical): code injection - "pricing rule preview" evaluates user input.
// Strong fix: a small expression parser / allowlisted operations, never eval or new Function.
router.post('/pricing/preview', (req, res) => {
  const { formula, price } = req.body || {};
  const result = eval(formula.replace(/price/g, String(Number(price))));
  res.json({ result });
});

// DEMO ALERT (true positive): server-side request forgery - fetches any URL the caller supplies
// (e.g. http://169.254.169.254/ cloud metadata). Strong fix: allowlist of partner hosts.
router.post('/webhooks/test', (req, res) => {
  https
    .get(req.body.url, (upstream) => res.status(upstream.statusCode).end())
    .on('error', () => res.status(502).end());
});

// DEMO ALERT (remediated): command injection in a backup helper.
router.post('/backup', (req, res) => {
  const { name } = req.query;
  if (typeof name !== 'string' || !/^[a-zA-Z0-9_-]{1,64}$/.test(name)) {
    return res.status(400).send('invalid backup name');
  }
  execFile('tar', ['-czf', `/tmp/${name}.tgz`, './data'], (err) => {
    if (err) return res.status(500).send('backup failed');
    res.status(202).end();
  });
});

// DEMO ALERT (true positive): regular expression injection / ReDoS (?pattern=(a+)+$).
router.get('/logs/search', (req, res) => {
  const re = new RegExp(req.query.pattern);
  const lines = ['GET /products 200', 'POST /login 401', 'GET /admin 403'];
  res.json(lines.filter((l) => re.test(l)));
});

module.exports = router;
