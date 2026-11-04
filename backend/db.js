
require('dotenv').config();

const mysql = require('mysql2/promise');

// Tạo kết nối đến MySQL
const db = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
});

// Xuất kết nối để các file khác sử dụng
module.exports = db;
