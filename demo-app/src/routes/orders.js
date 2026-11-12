const express = require('express');
const { db } = require('../db');

// Owner: team-checkout. Session 2/3 demo content (injection + XSS campaign themes).
const router = express.Router();

// DEMO ALERT (true positive): SQL injection through a route parameter.
// DEMO ALERT (true positive): stack trace exposure + reflected XSS in the error paths.
router.get('/:id', (req, res) => {
  db.get('SELECT id, product_id, qty, status FROM orders WHERE id = ' + req.params.id, (err, row) => {
    if (err) return res.status(500).send(err.stack);
    if (!row) return res.status(404).send(`<p>Order ${req.params.id} was not found</p>`);
    res.json(row);
  });
});

// DEMO ALERT (true positive): SQL injection in ORDER BY. Identifiers can't be bound as parameters,
// so a good fix needs an allowlist - a useful "review the Autofix suggestion" discussion.
router.get('/', (req, res) => {
  const sort = req.query.sort || 'id';
  db.all('SELECT id, product_id, qty, status FROM orders ORDER BY ' + sort, (err, rows) => {
    if (err) return res.status(500).send('Could not list orders');
    res.json(rows);
  });
});

// Safe pattern for contrast: parameterised status filter.
router.get('/status/:status', (req, res) => {
  db.all('SELECT id, status FROM orders WHERE status = ?', [req.params.status], (err, rows) => {
    if (err) return res.status(500).end();
    res.json(rows);
  });
});

module.exports = router;
