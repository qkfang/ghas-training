const express = require('express');
const fs = require('fs');
const path = require('path');

// Owner: team-accounts. Session 2/3 demo content.
const router = express.Router();
const AVATAR_DIR = path.join(__dirname, '..', '..', 'public', 'avatars');

// DEMO ALERT (true positive): open redirect after login - phishing via ?returnUrl=https://evil.example
router.get('/login/callback', (req, res) => {
  res.redirect(req.query.returnUrl || '/');
});

// DEMO ALERT (true positive): reflected XSS in a greeting page.
router.get('/welcome', (req, res) => {
  res.send('<p>Welcome back, ' + req.query.name + '!</p>');
});

// DEMO ALERT (true positive): path traversal - no validation, unlike routes/files.js (?file=../../src/auth.js).
// Contrast with the guarded download in routes/files.js when discussing false positives (Session 1).
router.get('/avatar', (req, res) => {
  fs.readFile(path.join(AVATAR_DIR, req.query.file), (err, data) => {
    if (err) return res.status(404).end();
    res.type('png').send(data);
  });
});

module.exports = router;
