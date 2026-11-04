const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { once } = require('node:events');
const express = require('express');
const { createAuthRouter, createLimiter } = require('../auth/router');
const { tokenHash } = require('../auth/store');
const { hashPassword, verifyPassword } = require('../auth/passwords');

class MemoryStore {
  constructor() { this.users = new Map(); this.sessions = new Map(); }
  async register(input) {
    if (this.users.has(input.email)) throw Object.assign(new Error(), { code: 'ER_DUP_ENTRY' });
    const user = { id: this.users.size + 1, full_name: input.fullName, email: input.email,
      password_hash: input.passwordHash, role: 'user' };
    this.users.set(user.email, user); await this.createSession(user.id, input.token); return user;
  }
  async findByEmail(email) { return this.users.get(email); }
  async createSession(id, token) { this.sessions.set(tokenHash(token), { id, expires: Date.now() + 60000 }); }
  async findSession(token) {
    const session = this.sessions.get(tokenHash(token));
    return session && session.expires > Date.now() ? [...this.users.values()].find(u => u.id === session.id) : null;
  }
  async revoke(token) { this.sessions.delete(tokenHash(token)); }
}

let server, base, store;
before(async () => {
  store = new MemoryStore();
  const app = express(); app.use(express.json()); app.use('/api/auth', createAuthRouter(store));
  server = app.listen(0, '127.0.0.1'); await once(server, 'listening');
  base = `http://127.0.0.1:${server.address().port}/api/auth`;
});
after(() => { server.closeAllConnections(); server.close(); });
async function request(route, data, headers = {}) {
  const response = await fetch(base + route, { method: data === undefined ? 'GET' : 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Auth-Client': 'native', ...headers },
    body: data === undefined ? undefined : JSON.stringify(data) });
  return { response, body: response.status === 204 ? {} : await response.json() };
}
const password = 'Valid test password 2026!';

test('password hash is salted and verifies without storing plaintext', async () => {
  const a = await hashPassword(password), b = await hashPassword(password);
  assert.notEqual(a, b); assert(!a.includes(password));
  assert(await verifyPassword(password, a)); assert(!await verifyPassword('wrong', a));
  assert(!await verifyPassword(password, 'invalid'));
});
test('register, login, cookie restore, and server-side logout work', async () => {
  const registration = await request('/register', { fullName: ' Test User ', email: ' TEST@example.invalid ', password, role: 'admin' });
  assert.equal(registration.response.status, 201);
  assert.equal(registration.body.user.fullName, 'Test User');
  assert.equal(registration.body.user.email, 'test@example.invalid');
  assert.equal(registration.body.user.role, 'user');
  assert.equal(registration.body.user.password_hash, undefined);
  const cookie = registration.response.headers.get('set-cookie');
  assert.match(cookie, /HttpOnly/i); assert.match(cookie, /SameSite=Strict/i);
  assert(!store.sessions.has(registration.body.sessionToken));
  const restored = await request('/me', undefined, { Cookie: cookie.split(';')[0] });
  assert.equal(restored.response.status, 200);
  const wrong = await request('/login', { email: 'test@example.invalid', password: 'incorrect' });
  assert.equal(wrong.response.status, 401);
  const missing = await request('/login', { email: 'missing@example.invalid', password: 'incorrect' });
  assert.equal(missing.response.status, 401); assert.deepEqual(wrong.body, missing.body);
  const login = await request('/login', { email: 'test@example.invalid', password });
  assert.equal(login.response.status, 200);
  assert.notEqual(login.body.sessionToken, registration.body.sessionToken);
  const authorization = `Bearer ${login.body.sessionToken}`;
  assert.equal((await request('/me', undefined, { authorization })).response.status, 200);
  assert.equal((await request('/logout', {}, { authorization, Origin: 'https://attacker.invalid' })).response.status, 403);
  assert.equal((await request('/me', undefined, { authorization })).response.status, 200);
  assert.equal((await request('/logout', {}, { authorization })).response.status, 204);
  assert.equal((await request('/me', undefined, { authorization })).response.status, 401);
});
test('registration accepts eight characters and rejects seven', async () => {
  const input = { fullName: 'Password Test', email: 'eight@example.invalid', password: '1234567' };
  assert.equal((await request('/register', input)).response.status, 400);
  input.password = '12345678';
  assert.equal((await request('/register', input)).response.status, 201);
  assert.equal((await request('/login', { email: input.email, password: input.password })).response.status, 200);
});

test('web login never exposes the session token in JSON', async () => {
  const result = await request('/register', { fullName: 'Web User', email: 'web@example.invalid', password }, { 'X-Auth-Client': 'web' });
  assert.equal(result.response.status, 201); assert.equal(result.body.sessionToken, undefined);
});
test('duplicate email and invalid or non-string input are rejected', async () => {
  await request('/register', { fullName: 'Dup', email: 'dup@example.invalid', password });
  assert.equal((await request('/register', { fullName: 'Dup', email: 'dup@example.invalid', password })).response.status, 409);
  assert.equal((await request('/register', { fullName: 'Bad', email: {}, password })).response.status, 400);
  assert.equal((await request('/login', { email: [], password })).response.status, 400);
  assert.equal((await request('/register', { fullName: 'Bad', email: 'bad@example.invalid', password: 'short' })).response.status, 400);
});
test('expired sessions cannot authenticate', async () => {
  const result = await request('/login', { email: 'web@example.invalid', password });
  store.sessions.get(tokenHash(result.body.sessionToken)).expires = 0;
  assert.equal((await request('/me', undefined, { authorization: `Bearer ${result.body.sessionToken}` })).response.status, 401);
});
test('rate limiter rejects repeated attempts', async () => {
  const app = express(); app.use(createLimiter(2)); app.get('/', (_, res) => res.json({ ok: true }));
  const local = app.listen(0, '127.0.0.1'); await once(local, 'listening');
  try {
    const url = `http://127.0.0.1:${local.address().port}`;
    assert.equal((await fetch(url)).status, 200); assert.equal((await fetch(url)).status, 200);
    const limited = await fetch(url); assert.equal(limited.status, 429); assert(limited.headers.get('retry-after'));
  } finally { local.closeAllConnections(); local.close(); }
});
