const express = require('express');
const _ = require('lodash');
const { db } = require('../db');

const router = express.Router();

// DEMO ALERT (true positive, P1): SQL injection + reflected XSS on a public endpoint.
router.get('/search', (req, res) => {
  const term = req.query.q || '';
  const sql = "SELECT id, name, price FROM products WHERE name LIKE '%" + term + "%'";
  db.all(sql, (err, rows) => {
    if (err) return res.status(500).send('Search failed');
    const items = rows.map((r) => `<li>${_.escape(r.name)} - $${r.price}</li>`).join('');
    res.send(`<h1>Results for ${term}</h1><ul>${items}</ul>`);
  });
});

// Safe pattern for contrast: parameterised query, no alert expected.
router.get('/:id', (req, res) => {
  db.get('SELECT id, name, price FROM products WHERE id = ?', [req.params.id], (err, row) => {
    if (err || !row) return res.status(404).end();
    res.json(row);
  });
});

// Only lodash.chunk/escape are used - relevant when triaging lodash Dependabot alerts.
router.get('/', (req, res) => {
  db.all('SELECT id, name, price FROM products', (err, rows) => {
    if (err) return res.status(500).end();
    res.json(_.chunk(rows, 10));
  });
});

module.exports = router;
