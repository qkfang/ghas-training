const express = require('express');
const { db } = require('../db');

// Owner: team-catalog. Session 2/3 demo content (injection + XSS campaign themes).
const router = express.Router();

// DEMO ALERT (true positive): SQL injection in an INSERT built from the request body.
router.post('/', (req, res) => {
  const { productId, rating, body } = req.body || {};
  const sql =
    'INSERT INTO reviews (product_id, rating, body) VALUES (' + productId + ', ' + rating + ", '" + body + "')";
  db.run(sql, (err) => {
    if (err) return res.status(500).send('Could not save review');
    res.status(201).end();
  });
});

// DEMO ALERT (true positive): reflected XSS - the product label is echoed into HTML unencoded.
router.get('/', (req, res) => {
  const product = req.query.product || '';
  db.all('SELECT rating, body FROM reviews WHERE product_id = ?', [req.query.productId], (err, rows) => {
    if (err) return res.status(500).end();
    const list = (rows || []).map((r) => `<li>${r.rating}/5</li>`).join('');
    res.send('<h2>Reviews for ' + product + '</h2><ul>' + list + '</ul>');
  });
});

module.exports = router;
