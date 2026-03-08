const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'yunxintong_enterprise_secret_2026';

function generateToken(payload, expiresIn = '7d') {
  return jwt.sign(payload, JWT_SECRET, { expiresIn });
}

function verifyToken(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ code: 401, message: '未登录或登录已过期' });
  }
  try {
    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ code: 401, message: '登录已过期，请重新登录' });
  }
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ code: 403, message: '无权限访问' });
    }
    next();
  };
}

module.exports = { generateToken, verifyToken, requireRole, JWT_SECRET };
