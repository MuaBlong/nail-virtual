const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { once } = require('node:events');
const express = require('express');
const { createHistoryRouter } = require('../auth/history');

const tokens = ['a'.repeat(43), 'b'.repeat(43)];
const saved = new Map();
let server, base;
before(async () => {
  const store = {
    async findSession(token) { const id = tokens.indexOf(token); return id < 0 ? null : { id: id + 1 }; },
    async saveHistory(userId, record) { const id = String(saved.size + 1); saved.set(id, { ...record, id, userId }); return id; },
    async listHistory(userId, offset) {
      return [...saved.values()].filter(r => r.userId === userId).slice(offset, offset + 10)
        .map(r => ({ ...r, before: r.before.toString('base64'), result: r.result.toString('base64') }));
    },
    async removeHistory(userId, id) {
      if (saved.get(id)?.userId !== userId) return false;
      return saved.delete(id);
    },
  };
  const app = express();
  app.use('/api/auth/history', createHistoryRouter(store));
  server = app.listen(0, '127.0.0.1'); await once(server, 'listening');
  base = `http://127.0.0.1:${server.address().port}/api/auth/history`;
});
after(() => { server.closeAllConnections(); server.close(); });
const image = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
const record = { before: image, result: image, set: { id: 'pink', name: 'Pink', category: 'Plain', pattern: 'solid', images: [], palette: [0xffeeaabb] } };
function request(method, path = '', body, token = tokens[0], extra = {}) {
  return fetch(base + path, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...extra }, body: body === undefined ? undefined : JSON.stringify(body) });
}
test('history requires a valid account and rejects foreign origins', async () => {
  assert.equal((await request('GET', '', undefined, null)).status, 401);
  assert.equal((await request('POST', '', record, tokens[0], { Origin: 'https://attacker.invalid' })).status, 403);
});
test('saved images belong only to their account and can be deleted', async () => {
  const created = await request('POST', '', { ...record, userId: 2 });
  assert.equal(created.status, 201);
  const { id } = await created.json();
  const own = await (await request('GET')).json();
  assert.equal(own.records.length, 1);
  assert.equal(own.records[0].result, image);
  assert.deepEqual((await (await request('GET', '', undefined, tokens[1])).json()).records, []);
  assert.equal((await request('DELETE', '/' + id, undefined, tokens[1])).status, 404);
  assert.equal((await request('DELETE', '/' + id)).status, 204);
  assert.deepEqual((await (await request('GET')).json()).records, []);
});
test('invalid image, metadata, oversized image and pagination are rejected', async () => {
  assert.equal((await request('POST', '', { ...record, result: 'not an image' })).status, 400);
  assert.equal((await request('POST', '', { ...record, set: {} })).status, 400);
  assert.equal((await request('POST', '', { ...record, result: Buffer.alloc(1024 * 1024 + 1).toString('base64') })).status, 400);
  assert.equal((await request('GET', '?offset=-1')).status, 400);
});
