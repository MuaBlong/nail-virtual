const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { access } = require('node:fs/promises');
const { MysqlAuthStore } = require('../auth/store');
const { managedPath } = require('../auth/history_files');

test('failed history insert rolls back and removes the newly written image files', async () => {
  const id = randomUUID();
  let queries = 0, rolledBack = false, released = false;
  const connection = {
    async beginTransaction() {},
    async execute() {
      if (++queries === 1) return [{ insertId: 100 }];
      throw new Error('Synthetic insert failure');
    },
    async rollback() { rolledBack = true; },
    release() { released = true; },
  };
  const store = new MysqlAuthStore({ async getConnection() { return connection; } });
  const image = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  await assert.rejects(store.saveHistory(1, {
    id, before: image, result: image, set: { id: 'custom', name: 'Test' },
  }), /Synthetic insert failure/);
  assert(rolledBack); assert(released);
  await assert.rejects(access(managedPath(`storage/try-on/${id}/before.png`)), { code: 'ENOENT' });
  await assert.rejects(access(managedPath(`storage/try-on/${id}/result.png`)), { code: 'ENOENT' });
});

test('database paths cannot read or delete outside the managed image directory', () => {
  for (const value of ['../.env', 'C:/Windows/test.png', 'storage/try-on/../../.env', null]) {
    assert.throws(() => managedPath(value), /Invalid history image path/);
  }
});
