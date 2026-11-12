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
const backupRequests = new Map();
const BACKUP_RATE_LIMIT = 3;
const BACKUP_RATE_WINDOW_MS = 60_000;
const BACKUP_RATE_LIMIT_MAX_CLIENTS = 10_000;

function rateLimitBackup(req, res, next) {
  const now = Date.now();
  const key = req.ip;
  let requestWindow = backupRequests.get(key);
  if (!requestWindow || now - requestWindow.start >= BACKUP_RATE_WINDOW_MS) {
    requestWindow = { start: now, count: 0 };
  }
  if (requestWindow.count >= BACKUP_RATE_LIMIT) {
    return res.status(429).send('too many backup requests');
  }
  requestWindow.count += 1;
  backupRequests.delete(key);
  backupRequests.set(key, requestWindow);
  if (backupRequests.size > BACKUP_RATE_LIMIT_MAX_CLIENTS) {
    backupRequests.delete(backupRequests.keys().next().value);
  }
  next();
}

router.post('/backup', (req, res, next) => {
  const { name } = req.query;
  if (typeof name !== 'string' || !/^[a-zA-Z0-9_-]{1,64}$/.test(name)) {
    return res.status(400).send('invalid backup name');
  }
  next();
}, rateLimitBackup, (req, res) => {
  execFile('tar', ['-czf', `/tmp/${req.query.name}.tgz`, './data'], (err) => {
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
