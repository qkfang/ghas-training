const express = require('express');
const fs = require('fs');
const path = require('path');

const router = express.Router();
const REPORT_DIR = path.join(__dirname, '..', '..', 'reports');

// DEMO ALERT (risk-accepted candidate): "Missing rate limiting" on an endpoint that hits the
// file system. In this scenario rate limiting is enforced at the API gateway (compensating control).
router.get('/latest', (req, res) => {
  fs.readFile(path.join(REPORT_DIR, 'latest.json'), 'utf8', (err, data) => {
    if (err) return res.status(404).end();
    res.type('application/json').send(data);
  });
});

module.exports = router;
