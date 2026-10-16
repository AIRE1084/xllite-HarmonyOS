'use strict';
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const ts = require(process.env.XJIT_TYPESCRIPT_PATH || 'D:/data/devecostudionext/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
const tests = [];
function test(name, run) { tests.push({ name, run }); }
function fixture() {
  const state = { epoch: 1, requests: [], destroyed: 0, saved: [], response: { responseCode: 200, result: JSON.stringify({ ok: true, data: {} }) } };
  const module = { exports: {} };
  const source = fs.readFileSync(path.join(root, 'entry/src/main/ets/services/XlliteGateway.ets'), 'utf8');
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText, {
    module, exports: module.exports, Date, require(spec) {
      if (spec === '@ohos.net.http') return { default: { RequestMethod: { POST: 'POST', GET: 'GET' }, createHttp() { return {
        async request(url, options) { state.requests.push({ url, ...options }); if (state.networkError) throw new Error('offline'); return state.response; }, destroy() { state.destroyed++; },
      }; } } };
      if (spec.endsWith('/MemoryCache')) return { getCacheEpoch: () => state.epoch };
      if (spec.endsWith('/AuthManager')) return { async saveSchoolSession(...args) { state.saved.push(args); }, getUsername: () => 'sample', getAccessToken: () => 'opaque-token', isGatewayAuth: () => true, async clearSession() { state.cleared = true; state.epoch++; }, async clearAccessToken() {} };
      throw new Error(spec);
    },
  });
  return { state, api: module.exports };
}
test('login posts native credentials over HTTPS without retaining them', async () => { const f = fixture(); await f.api.gatewayLogin('sample', 'fixture-secret', '1234'); const q = f.state.requests[0]; assert.equal(q.url, 'https://xllite.sayqz.com/api/v1/auth/login'); assert.equal(JSON.parse(q.extraData).captcha, '1234'); assert.equal(f.state.destroyed, 1); assert.equal(f.state.saved.length, 0); });
test('HTTP401 preserves structured login error and is not a network failure', async () => { const f = fixture(); f.state.response = { responseCode: 401, result: JSON.stringify({ ok: false, error: '账号或密码错误' }) }; const r = await f.api.gatewayLogin('sample', 'fixture'); assert.equal(r.error, '账号或密码错误'); assert.equal(r.statusCode, 401); assert.equal(r.networkError, false); });
test('network failures have explicit transport classification', async () => { const f = fixture(); f.state.networkError = true; const r = await f.api.gatewayLogin('sample', 'fixture'); assert.equal(r.networkError, true); assert.equal(f.state.destroyed, 1); });
test('missing expiry never creates invented 24h session', async () => { const f = fixture(); const r = await f.api.acceptGatewayLogin('sample', { accessToken: 'opaque-token', username: 'sample' }); assert.equal(r.ok, false); assert.equal(f.state.saved.length, 0); });
test('expired expiry never reports successful persistence', async () => { const f = fixture(); const r = await f.api.acceptGatewayLogin('sample', { accessToken: 'opaque-token', expiresAt: 1 }); assert.equal(r.ok, false); assert.equal(f.state.saved.length, 0); });
test('valid gateway session is persisted with server expiry and source', async () => { const f = fixture(); const exp = Date.now() + 60000; const r = await f.api.acceptGatewayLogin('sample', { accessToken: 'opaque-token', expiresAt: exp }); assert.equal(r.ok, true); assert.equal(f.state.saved[0][2], exp); assert.equal(f.state.saved[0][4], 'xllite-gateway'); });
test('retired session cannot persist login', async () => { const f = fixture(); const r = await f.api.acceptGatewayLogin('sample', { accessToken: 'opaque-token', expiresInSeconds: 60 }, 0); assert.equal(r.ok, false); assert.equal(f.state.saved.length, 0); });
test('refresh uses bearer header without duplicating token in JSON body', async () => { const f = fixture(); await f.api.gatewayRefresh('opaque-token'); assert.equal(f.state.requests[0].header.Authorization, 'Bearer opaque-token'); assert.deepEqual(JSON.parse(f.state.requests[0].extraData), {}); });
test('business uses single bearer token and no CAS credentials', async () => { const f = fixture(); await f.api.gatewayRun('newcard.balance', 'opaque-token', {}); const q = f.state.requests[0]; assert.equal(q.header.Authorization, 'Bearer opaque-token'); assert.deepEqual(JSON.parse(q.extraData), { feature: 'newcard.balance', params: {} }); });
test('explicit gateway logout clears locally and revokes only captured token', async () => { const f = fixture(); await f.api.logoutGatewayAccount(); assert.equal(f.state.cleared,true); assert.equal(f.state.requests[0].url,'https://xllite.sayqz.com/api/v1/auth/logout'); assert.equal(f.state.requests[0].header.Authorization,'Bearer opaque-token'); });
test('concurrent refresh shares one rotation and persists exactly once', async () => { const f = fixture(); f.state.response.result=JSON.stringify({ok:true,data:{accessToken:'rotated',expiresInSeconds:60}}); const results=await Promise.all([f.api.refreshGatewayAccount(),f.api.refreshGatewayAccount()]); assert.ok(results.every(r=>r.ok)); assert.equal(f.state.requests.length,1); assert.equal(f.state.saved.length,1); });
(async () => { let failed = 0; for (const t of tests) { try { await t.run(); console.log('PASS ' + t.name); } catch (e) { failed++; console.error('FAIL ' + t.name + ': ' + e.message); } } console.log(`${tests.length} gateway checks, ${failed} failed`); process.exitCode = failed ? 1 : 0; })();
