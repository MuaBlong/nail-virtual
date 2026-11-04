const express = require('express');
const { randomUUID } = require('node:crypto');
const { sessionToken, createLimiter } = require('./router');
const { allowedOrigin } = require('./origins');

function decodeImage(value) {
  if (typeof value !== 'string' || value.length > 1400000 ||
      value.length % 4 !== 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(value)) return null;
  const bytes = Buffer.from(value, 'base64');
  const jpeg = bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const png = bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  return bytes.length > 0 && bytes.length <= 1024 * 1024 && (jpeg || png) ? bytes : null;
}

function validSet(set) {
  return set && typeof set === 'object' && !Array.isArray(set) &&
    ['id', 'name', 'category', 'pattern'].every(key => typeof set[key] === 'string' && set[key].length <= 200) &&
    set.name.trim() && Array.isArray(set.images) && set.images.length <= 5 &&
    set.images.every(item => typeof item === 'string') &&
    Array.isArray(set.palette) && set.palette.length <= 20 &&
    set.palette.every(item => Number.isInteger(item) && item >= 0 && item <= 0xffffffff) &&
    Buffer.byteLength(JSON.stringify(set)) <= 2 * 1024 * 1024;
}

function createHistoryRouter(store) {
  const router = express.Router();
  router.use(async (req, res, next) => {
    res.set('Cache-Control', 'no-store');
    if (!allowedOrigin(req.get('origin'))) return res.status(403).json({ message: 'Nguồn yêu cầu không được phép.' });
    const token = sessionToken(req);
    if (!token || !/^[A-Za-z0-9_-]{43}$/.test(token)) return res.status(401).json({ message: 'Hãy đăng nhập để lưu và xem mẫu nail.' });
    try {
      const user = await store.findSession(token);
      if (!user) return res.status(401).json({ message: 'Phiên đã hết hạn. Hãy đăng nhập lại.' });
      req.accountId = user.id;
      next();
    } catch (_) { res.status(503).json({ message: 'Chưa kết nối được kho mẫu đã lưu.' }); }
  });
  router.post('/', createLimiter(30), (req, res, next) => {
    if (!req.is('application/json')) return res.status(415).json({ message: 'Yêu cầu cần gửi dữ liệu JSON.' });
    next();
  }, express.json({ limit: '6mb' }), async (req, res) => {
    const before = decodeImage(req.body?.before), result = decodeImage(req.body?.result);
    if (!before || !result || !validSet(req.body?.set)) {
      return res.status(400).json({ message: 'Ảnh hoặc thông tin mẫu không hợp lệ (tối đa 1 MB mỗi ảnh).' });
    }
    try {
      const id = await store.saveHistory(req.accountId, { id: randomUUID(), before, result, set: req.body.set });
      res.status(201).json({ id });
    } catch (_) { res.status(503).json({ message: 'Chưa lưu được mẫu vào tài khoản. Hãy thử lại.' }); }
  });
  router.get('/', async (req, res) => {
    const offset = Number(req.query.offset || 0);
    if (!Number.isSafeInteger(offset) || offset < 0 || offset > 1000000) return res.status(400).json({ message: 'Trang lịch sử không hợp lệ.' });
    try { res.json({ records: await store.listHistory(req.accountId, offset) }); }
    catch (_) { res.status(503).json({ message: 'Chưa tải được mẫu đã lưu. Hãy thử lại.' }); }
  });
  router.delete('/:id', async (req, res) => {
    if (!/^[1-9]\d{0,9}$/.test(req.params.id)) return res.status(400).json({ message: 'Mã mẫu không hợp lệ.' });
    try {
      if (!await store.removeHistory(req.accountId, req.params.id)) return res.status(404).json({ message: 'Không tìm thấy mẫu đã lưu.' });
      res.status(204).end();
    } catch (_) { res.status(503).json({ message: 'Chưa xóa được mẫu. Hãy thử lại.' }); }
  });
  return router;
}
module.exports = { createHistoryRouter };
