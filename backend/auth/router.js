const express = require('express');
const { randomBytes } = require('node:crypto');
const { hashPassword, verifyPassword } = require('./passwords');
const { allowedOrigin } = require('./origins');

const COOKIE = 'nail_session';
const cookieOptions = () => ({ httpOnly: true, sameSite: 'strict',
  secure: process.env.NODE_ENV === 'production', path: '/api/auth' });
const publicUser = user => ({ id: String(user.id), fullName: user.full_name, email: user.email, role: user.role || 'user' });

function sessionToken(req) {
  const authorization = req.get('authorization') || '';
  if (authorization.startsWith('Bearer ')) return authorization.slice(7);
  const item = (req.get('cookie') || '').split(';').map(s => s.trim()).find(s => s.startsWith(COOKIE + '='));
  return item ? item.slice(COOKIE.length + 1) : null;
}
function createLimiter(max = 20, windowMs = 15 * 60 * 1000) {
  const attempts = new Map();
  return (req, res, next) => {
    const now = Date.now(), key = req.ip;
    for (const [ip, item] of attempts) if (item.expires <= now) attempts.delete(ip);
    const current = attempts.get(key) || { count: 0, expires: now + windowMs };
    if (current.count >= max) {
      res.set('Retry-After', String(Math.ceil((current.expires - now) / 1000)));
      return res.status(429).json({ message: 'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau ít phút.' });
    }
    if (attempts.size >= 10000 && !attempts.has(key)) attempts.delete(attempts.keys().next().value);
    current.count++; attempts.set(key, current); next();
  };
}
function validEmail(email) {
  return typeof email === 'string' && email.length <= 150 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function createAuthRouter(store, { limiter = createLimiter() } = {}) {
  const router = express.Router();
  // A slow dummy hash avoids a fast path that reveals an unknown email at login.
  let dummyHash;
  const dummy = () => dummyHash ||= hashPassword(randomBytes(24).toString('base64url'));
  router.use((req, res, next) => {
    res.set('Cache-Control', 'no-store');
    if (!allowedOrigin(req.get('origin'))) return res.status(403).json({ message: 'Nguồn yêu cầu không được phép.' });
    if (req.method === 'POST' && !req.is('application/json')) return res.status(415).json({ message: 'Yêu cầu cần gửi dữ liệu JSON.' });
    next();
  });
  function signedIn(req, res, user, token, status = 200) {
    res.cookie(COOKIE, token, { ...cookieOptions(), maxAge: 7 * 86400 * 1000 });
    const result = { user: publicUser(user) };
    // The web uses only HttpOnly cookies. Native apps keep their token in memory.
    if (req.get('X-Auth-Client') === 'native') result.sessionToken = token;
    res.status(status).json(result);
  }
  router.post('/register', limiter, async (req, res) => {
    const { fullName, email, password } = req.body || {};
    const normalizedEmail = typeof email === 'string' ? email.trim().toLowerCase() : '';
    if (typeof fullName !== 'string' || !fullName.trim() || fullName.trim().length > 100 || !validEmail(normalizedEmail)) {
      return res.status(400).json({ message: 'Hãy nhập họ tên (tối đa 100 ký tự) và email hợp lệ.' });
    }
    if (typeof password !== 'string' || password.length < 8 || password.length > 128) {
      return res.status(400).json({ message: 'Mật khẩu cần từ 8 đến 128 ký tự.' });
    }
    try {
      const token = randomBytes(32).toString('base64url');
      const user = await store.register({ fullName: fullName.trim(), email: normalizedEmail,
        passwordHash: await hashPassword(password), token });
      signedIn(req, res, user, token, 201);
    } catch (error) {
      if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({ message: 'Email này đã được đăng ký. Hãy đăng nhập hoặc dùng email khác.' });
      res.status(503).json({ message: 'Chưa tạo được tài khoản. Vui lòng thử lại sau.' });
    }
  });
  router.post('/login', limiter, async (req, res) => {
    const { email, password } = req.body || {};
    const normalizedEmail = typeof email === 'string' ? email.trim().toLowerCase() : '';
    if (!validEmail(normalizedEmail) || typeof password !== 'string' || password.length > 128 || !password) {
      return res.status(400).json({ message: 'Hãy nhập email và mật khẩu hợp lệ.' });
    }
    try {
      const user = await store.findByEmail(normalizedEmail);
      const matches = await verifyPassword(password, user?.password_hash || await dummy());
      if (!user || !matches) return res.status(401).json({ message: 'Email hoặc mật khẩu không đúng.' });
      const token = randomBytes(32).toString('base64url');
      await store.createSession(user.id, token);
      signedIn(req, res, user, token);
    } catch (_) { res.status(503).json({ message: 'Chưa đăng nhập được. Vui lòng thử lại sau.' }); }
  });
  router.get('/me', async (req, res) => {
    const token = sessionToken(req);
    if (!token || !/^[A-Za-z0-9_-]{43}$/.test(token)) return res.status(401).json({ message: 'Bạn chưa đăng nhập hoặc phiên đã hết hạn.' });
    try {
      const user = await store.findSession(token);
      if (!user) return res.status(401).json({ message: 'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.' });
      res.json({ user: publicUser(user) });
    } catch (_) { res.status(503).json({ message: 'Chưa kiểm tra được phiên đăng nhập.' }); }
  });
  router.post('/logout', async (req, res) => {
    try {
      const token = sessionToken(req);
      if (token && /^[A-Za-z0-9_-]{43}$/.test(token)) await store.revoke(token);
      res.clearCookie(COOKIE, cookieOptions());
      res.status(204).end();
    } catch (_) { res.status(503).json({ message: 'Chưa đăng xuất được. Hãy kiểm tra kết nối và thử lại.' }); }
  });
  return router;
}
module.exports = { createAuthRouter, createLimiter, sessionToken };
