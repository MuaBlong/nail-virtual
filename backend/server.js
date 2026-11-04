
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const db = require('./db');
const activeCatalog = require('./catalog.json');
const plainCatalog = require('./plain_catalog.json');
const { MysqlAuthStore, ensureAuthSchema } = require('./auth/store');
const { createAuthRouter } = require('./auth/router');
const { allowedOrigin } = require('./auth/origins');
const { createHistoryRouter } = require('./auth/history');

const app = express();

// Cho phép Flutter Web gọi API
app.use(cors({ origin: (origin, callback) => callback(null, allowedOrigin(origin)), credentials: true }));

// Cho phép nhận dữ liệu JSON
app.use('/api/auth/history', createHistoryRouter(new MysqlAuthStore(db)));
app.use(express.json({ limit: '32kb' }));
app.use('/api/auth', createAuthRouter(new MysqlAuthStore(db)));

// API kiểm tra Backend
app.get('/', (req, res) => {
  res.json({
    message: 'Backend Nail Virtual đang hoạt động'
  });
});

// API kiểm tra MySQL
app.get('/api/test-db', async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT DATABASE() AS database_name'
    );

    res.json({
      success: true,
      message: 'Kết nối MySQL thành công',
      database: rows[0].database_name
    });
  } catch (error) {
    console.error('Lỗi MySQL:', error.message);

    res.status(500).json({
      success: false,
      message: 'Không thể kết nối MySQL',
      error: error.message
    });
  }
});

// API lấy danh sách bộ Nail
app.get('/api/nail-sets', (req, res) => {
  res.json([...plainCatalog, ...activeCatalog]);
});

app.use((error, req, res, next) => {
  if (res.headersSent) return next(error);
  const status = error.status === 413 ? 413 : error instanceof SyntaxError ? 400 : 500;
  res.status(status).json({ message: status === 413 ? 'Dữ liệu gửi lên quá lớn.' :
    status === 400 ? 'Dữ liệu JSON không hợp lệ.' : 'Máy chủ chưa xử lý được yêu cầu.' });
});

// Khởi chạy Backend
const PORT = Number(process.env.PORT || 5000);

if (require.main === module) ensureAuthSchema(db).then(() => app.listen(PORT, process.env.HOST || '127.0.0.1', () => {
  console.log('================================');
  console.log('NAIL VIRTUAL BACKEND');
  console.log(`Server: http://localhost:${PORT}`);
  console.log('================================');
})).catch(error => { console.error('Không khởi tạo được xác thực:', error.code || error.message); process.exitCode = 1; db.end(); });
module.exports = app;
