const express = require('express');
const path = require('path');
const { assertSafeFileName } = require('../utils/validate');

const router = express.Router();
const DOCS_DIR = path.join(__dirname, '..', '..', 'docs');

// DEMO ALERT (likely false positive): CodeQL may report path injection because it
// does not model that assertSafeFileName() throws for anything except "name.pdf".
router.get('/download', (req, res) => {
  const name = String(req.query.name || '');
  assertSafeFileName(name);
  res.sendFile(path.join(DOCS_DIR, name));
});

module.exports = router;
