const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET) {
  throw new Error('JWT_SECRET environment variable is required');
}

const jwt = require('jsonwebtoken');

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
