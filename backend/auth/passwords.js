const { randomBytes, scrypt, timingSafeEqual } = require('node:crypto');
const { promisify } = require('node:util');
const derive = promisify(scrypt);
const options = { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };

async function hashPassword(password) {
  const salt = randomBytes(16);
  const key = await derive(password, salt, 64, options);
  return `scrypt$32768$8$1$${salt.toString('base64')}$${key.toString('base64')}`;
}
async function verifyPassword(password, encoded) {
  const parts = String(encoded).split('$');
  if (parts.length !== 6 || parts.slice(0,4).join('$') !== 'scrypt$32768$8$1') return false;
  const salt = Buffer.from(parts[4], 'base64'), expected = Buffer.from(parts[5], 'base64');
  if (salt.length !== 16 || expected.length !== 64) return false;
  const actual = await derive(password, salt, 64, options);
  return timingSafeEqual(actual, expected);
}
module.exports = { hashPassword, verifyPassword };
