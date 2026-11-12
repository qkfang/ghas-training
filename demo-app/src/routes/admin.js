const express = require('express');
const { exec } = require('child_process');

const router = express.Router();

// DEMO ALERT (true positive, P0 if internet-facing): OS command injection.
// Mounted behind requireAdmin, which lowers likelihood but does not remove the flaw.
router.post('/diagnostics/ping', (req, res) => {
  const host = req.body.host;
  exec('ping -c 1 ' + host, (err, stdout) => {
    if (err) return res.status(500).send('ping failed');
    res.type('text/plain').send(stdout);
  });
});

module.exports = router;
