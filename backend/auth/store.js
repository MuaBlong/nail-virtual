const { createHash } = require('node:crypto');
const { writeFiles, readFiles, removeFiles } = require('./history_files');
const tokenHash = token => createHash('sha256').update(token).digest('hex');

async function ensureAuthSchema(db) {
  await db.query(`CREATE TABLE IF NOT EXISTS users (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('user','admin') DEFAULT 'user',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
  await db.query(`CREATE TABLE IF NOT EXISTS user_sessions (
    token_hash CHAR(64) NOT NULL PRIMARY KEY,
    user_id INT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    INDEX idx_auth_user (user_id), INDEX idx_auth_expiry (expires_at),
    CONSTRAINT fk_auth_session_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  ) ENGINE=InnoDB`);
  await db.query(`CREATE TABLE IF NOT EXISTS nail_sets (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    description TEXT DEFAULT NULL,
    category VARCHAR(100) DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
  await db.query(`CREATE TABLE IF NOT EXISTS hand_images (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    image_path VARCHAR(500) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
  await db.query(`CREATE TABLE IF NOT EXISTS try_on_history (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    hand_image_id INT NOT NULL,
    set_id INT DEFAULT NULL,
    result_path VARCHAR(500) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (hand_image_id) REFERENCES hand_images(id),
    FOREIGN KEY (set_id) REFERENCES nail_sets(id) ON DELETE SET NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
}

class MysqlAuthStore {
  constructor(db) { this.db = db; }
  async register({ fullName, email, passwordHash, token }) {
    const connection = await this.db.getConnection();
    try {
      await connection.beginTransaction();
      const [result] = await connection.execute(
        "INSERT INTO users (full_name,email,password_hash,role) VALUES (?,?,?,'user')",
        [fullName, email, passwordHash]);
      await this.createSession(result.insertId, token, connection);
      await connection.commit();
      return { id: result.insertId, full_name: fullName, email, role: 'user' };
    } catch (error) { await connection.rollback(); throw error; }
    finally { connection.release(); }
  }
  async findByEmail(email) {
    const [rows] = await this.db.execute(
      'SELECT id,full_name,email,password_hash,role FROM users WHERE email=? LIMIT 1', [email]);
    return rows[0] || null;
  }
  async createSession(userId, token, connection = this.db) {
    await connection.execute('DELETE FROM user_sessions WHERE expires_at <= UTC_TIMESTAMP()');
    await connection.execute(
      'INSERT INTO user_sessions (token_hash,user_id,expires_at) VALUES (?,?,DATE_ADD(UTC_TIMESTAMP(),INTERVAL 7 DAY))',
      [tokenHash(token), userId]);
  }
  async findSession(token) {
    const [rows] = await this.db.execute(`SELECT u.id,u.full_name,u.email,u.role
      FROM user_sessions s JOIN users u ON u.id=s.user_id
      WHERE s.token_hash=? AND s.expires_at>UTC_TIMESTAMP() LIMIT 1`, [tokenHash(token)]);
    return rows[0] || null;
  }
  async revoke(token) {
    await this.db.execute('DELETE FROM user_sessions WHERE token_hash=?', [tokenHash(token)]);
  }
  async saveHistory(userId, record) {
    const files = await writeFiles(record);
    let connection;
    try {
      connection = await this.db.getConnection();
      await connection.beginTransaction();
      const [hand] = await connection.execute(
        'INSERT INTO hand_images (user_id,image_path) VALUES (?,?)', [userId, files.beforePath]);
      let setId = null;
      if (/^[1-9]\d{0,9}$/.test(record.set.id)) {
        const [sets] = await connection.execute('SELECT id FROM nail_sets WHERE id=?', [record.set.id]);
        setId = sets[0]?.id ?? null;
      }
      const [history] = await connection.execute(
        'INSERT INTO try_on_history (user_id,hand_image_id,set_id,result_path) VALUES (?,?,?,?)',
        [userId, hand.insertId, setId, files.resultPath]);
      await connection.commit();
      return String(history.insertId);
    } catch (error) {
      if (connection) await connection.rollback();
      await removeFiles(files.beforePath, files.resultPath);
      throw error;
    } finally { connection?.release(); }
  }
  async listHistory(userId, offset) {
    const [rows] = await this.db.query(
      `SELECT h.id,UNIX_TIMESTAMP(h.created_at) AS created_epoch,i.image_path,h.result_path
       FROM try_on_history h JOIN hand_images i ON i.id=h.hand_image_id AND i.user_id=h.user_id
       WHERE h.user_id=? ORDER BY h.created_at DESC,h.id DESC LIMIT 10 OFFSET ?`,
      [userId, offset]);
    return Promise.all(rows.map(async row => ({
      id: String(row.id), created: new Date(Number(row.created_epoch) * 1000).toISOString(),
      ...await readFiles(row),
    })));
  }
  async removeHistory(userId, id) {
    const connection = await this.db.getConnection();
    let files;
    try {
      await connection.beginTransaction();
      const [rows] = await connection.execute(
        `SELECT h.hand_image_id,h.result_path,i.image_path FROM try_on_history h
         JOIN hand_images i ON i.id=h.hand_image_id AND i.user_id=h.user_id
         WHERE h.id=? AND h.user_id=? FOR UPDATE`, [id, userId]);
      if (!rows.length) { await connection.rollback(); return false; }
      files = rows[0];
      await connection.execute('DELETE FROM try_on_history WHERE id=? AND user_id=?', [id, userId]);
      const [references] = await connection.execute('SELECT id FROM try_on_history WHERE hand_image_id=? LIMIT 1', [files.hand_image_id]);
      if (!references.length) {
        await connection.execute('DELETE FROM hand_images WHERE id=? AND user_id=?', [files.hand_image_id, userId]);
      } else { files = null; }
      await connection.commit();
    } catch (error) { await connection.rollback(); throw error; }
    finally { connection.release(); }
    if (files) await removeFiles(files.image_path, files.result_path).catch(error => console.error('History file cleanup:', error.code || error.message));
    return true;
  }
}
module.exports = { MysqlAuthStore, ensureAuthSchema, tokenHash };
