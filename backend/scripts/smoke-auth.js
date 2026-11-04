// Creates only its own synthetic account, exercises real MySQL, then removes it.
const { randomBytes, randomUUID } = require('node:crypto');
const db = require('../db');
const { ensureAuthSchema, MysqlAuthStore } = require('../auth/store');
const { managedPath } = require('../auth/history_files');
const { readFile, access } = require('node:fs/promises');
const app = require('../server');
const { once } = require('node:events');

(async () => {
  const email = `auth-smoke-${randomUUID()}@example.invalid`;
  const password = randomBytes(24).toString('base64url');
  let userId, server;
  try {
    await ensureAuthSchema(db);
    server = app.listen(0, '127.0.0.1'); await once(server, 'listening');
    const base = `http://127.0.0.1:${server.address().port}/api/auth`;
    async function post(route, body, token, extraHeaders = {}) {
      return fetch(base + route, { method: 'POST', headers: { 'Content-Type': 'application/json',
        'X-Auth-Client': 'native', ...(token ? { Authorization: 'Bearer ' + token } : {}), ...extraHeaders }, body: JSON.stringify(body) });
    }
    const registered = await post('/register', { fullName: 'Synthetic Auth Test', email, password });
    if (registered.status !== 201) throw Error('Registration failed: ' + registered.status);
    const account = await registered.json(); userId = account.user.id;
    const [rows] = await db.execute('SELECT password_hash,role FROM users WHERE id=? AND email=?', [userId, email]);
    if (!rows[0].password_hash.startsWith('scrypt$') || rows[0].password_hash.includes(password) || rows[0].role !== 'user') throw Error('Invalid password storage');
    if ((await post('/register', { fullName: 'Duplicate', email, password })).status !== 409) throw Error('Duplicate not rejected');
    if ((await post('/login', { email, password: 'wrong password' })).status !== 401) throw Error('Wrong password accepted');
    const login = await post('/login', { email, password });
    if (login.status !== 200) throw Error('Login failed');
    const { sessionToken } = await login.json();
    if ((await fetch(base + '/me', { headers: { Authorization: 'Bearer ' + sessionToken } })).status !== 200) throw Error('Native session not restored');
    const webLogin = await post('/login', { email, password }, undefined, { 'X-Auth-Client': 'web' });
    if (webLogin.status !== 200 || (await webLogin.json()).sessionToken !== undefined) throw Error('Web login failed');
    const cookie = webLogin.headers.get('set-cookie')?.split(';')[0];
    if (!cookie) throw Error('Web session cookie missing');
    const headers = { Cookie: cookie, 'X-Auth-Client': 'web' };
    if ((await fetch(base + '/me', { headers })).status !== 200) throw Error('Web cookie session not restored');
    const image = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
    const saved = await post('/history', { before: image, result: image,
      set: { id: 'smoke', name: 'Smoke test', category: 'Plain', pattern: 'solid', images: [], palette: [0xffeeaabb] } }, undefined, headers);
    if (saved.status !== 201) throw Error('History save failed: ' + saved.status);
    const { id: historyId } = await saved.json();
    const [stored] = await db.execute(`SELECT h.user_id,h.hand_image_id,h.set_id,h.result_path,i.image_path,i.user_id AS image_user_id
      FROM try_on_history h JOIN hand_images i ON i.id=h.hand_image_id WHERE h.id=?`, [historyId]);
    if (String(stored[0]?.user_id) !== String(userId) || String(stored[0]?.image_user_id) !== String(userId)) throw Error('History and hand image not linked to account');
    if ((await readFile(managedPath(stored[0].result_path))).toString('base64') !== image ||
        (await readFile(managedPath(stored[0].image_path))).toString('base64') !== image) throw Error('Stored image paths do not point to saved images');
    if (stored[0].set_id !== null) throw Error('Non-database template should have a null set_id');
    const historyResponse = await fetch(base + '/history', { headers });
    if (historyResponse.status !== 200) throw Error('History list failed');
    const history = await historyResponse.json();
    if (history.records[0]?.id !== historyId || history.records[0]?.result !== image || !Number.isFinite(Date.parse(history.records[0]?.created))) throw Error('History not restored');
    const deleted = await fetch(base + '/history/' + historyId, { method: 'DELETE', headers });
    if (deleted.status !== 204) throw Error('History delete failed');
    const [remaining] = await db.execute('SELECT id FROM try_on_history WHERE id=?', [historyId]);
    if (remaining.length) throw Error('History still stored after deletion');
    const [remainingHands] = await db.execute('SELECT id FROM hand_images WHERE id=?', [stored[0].hand_image_id]);
    if (remainingHands.length) throw Error('Unused hand image still stored after deletion');
    for (const relative of [stored[0].image_path, stored[0].result_path]) {
      try { await access(managedPath(relative)); throw Error('Unused image file still exists'); }
      catch (error) { if (error.code !== 'ENOENT') throw error; }
    }
    if ((await post('/logout', {}, undefined, headers)).status !== 204) throw Error('Logout failed');
    if ((await fetch(base + '/me', { headers })).status !== 401) throw Error('Session not revoked');
    console.log('MySQL auth/history smoke: PASS (register, native login, web cookie login, save image, read image, delete image, logout)');
  } catch (error) { console.error(error.message); process.exitCode = 1; }
  finally {
    if (userId) {
      const store = new MysqlAuthStore(db);
      const [history] = await db.execute('SELECT id FROM try_on_history WHERE user_id=?', [userId]);
      for (const row of history) await store.removeHistory(userId, String(row.id));
      await db.execute('DELETE FROM users WHERE id=? AND email=?', [userId, email]);
    }
    if (server) { server.closeAllConnections(); server.close(); }
    await db.end();
  }
})();
