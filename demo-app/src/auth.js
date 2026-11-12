const jwt = require('jsonwebtoken');

// DEMO ALERT (true positive): hard-coded signing key in production code.
const JWT_SECRET = 'acme-super-secret-signing-key-2024';

function login(req, res) {
  const { username } = req.body || {};
  if (!username) return res.status(400).json({ error: 'username required' });
  const token = jwt.sign({ sub: username, role: username === 'alice' ? 'admin' : 'user' }, JWT_SECRET, {
    expiresIn: '1h',
  });
  res.json({ token });
}

function requireAdmin(req, res, next) {
  const header = req.headers.authorization || '';
  try {
    const claims = jwt.verify(header.replace('Bearer ', ''), JWT_SECRET);
    if (claims.role !== 'admin') return res.status(403).end();
    next();
  } catch {
    res.status(401).end();
  }
}

module.exports = { login, requireAdmin };
