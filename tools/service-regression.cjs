'use strict';
// Repeatable service regression checks. Runs actual .ets service code with mocked
// HarmonyOS preferences/HTTP; no credentials, network, installs or device needed.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const tsPath = process.env.XJIT_TYPESCRIPT_PATH || 'D:/data/devecostudionext/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js';
if (!fs.existsSync(tsPath)) throw new Error('Existing SDK TypeScript not found. Set XJIT_TYPESCRIPT_PATH; no download is attempted.');
const ts = require(tsPath);
const crypto = require('node:crypto');
function schoolJwt(exp = Math.floor(Date.now() / 1000) + 3600) { return Buffer.from('{}').toString('base64url') + '.' + Buffer.from(JSON.stringify({exp})).toString('base64url') + '.fixture'; }
function schoolResponse(request) {
  const data = request.url.includes('/personal/me/user') ? {code:0,data:{attributes:{accountId:'student',userName:'测试同学',organizationName:'测试学院'}}} :
    request.url.endsWith('/user/info') ? {success:true,resultData:{user:{balance:'12.34',username:'校园卡测试用户',idSerial:'fixture-card'}}} :
    {success:true,resultData:{rows:[{txdate:'2026-10-09 12:00:00',mername:'测试商户',txamt:'650'}],totalpage:1}};
  return {responseCode:200,result:JSON.stringify(data)};
}
const tests = [];
function test(name, run) { tests.push({ name, run }); }
function deferred() { let resolve; const promise = new Promise(r => { resolve = r; }); return { promise, resolve }; }
async function until(predicate) {
  for (let i = 0; i < 500; i++) { if (predicate()) return; await Promise.resolve(); }
  throw new Error('Expected asynchronous checkpoint was not reached');
}
function fixture() {
  const stores = new Map(), opens = new Map(), modules = new Map();
  const timers = new Map(); let nextTimer = 1;
  const state = { requests: [], created: 0, destroyed: 0, active: 0, peak: 0, appActive: true, mainPageActive: true, hook: null, respond: null };
  function prefs(name) {
    if (!stores.has(name)) stores.set(name, { data: new Map(), flushes: 0, reads: 0, writes: 0 });
    const store = stores.get(name);
    return {
      async get(key, fallback) { store.reads++; const value = store.data.has(key) ? store.data.get(key) : fallback; if (state.hook) await state.hook(name, 'get', key); return value; },
      async put(key, value) { store.writes++; if (state.hook) await state.hook(name, 'put', key); store.data.set(key, value); },
      async delete(key) { if (state.hook) await state.hook(name, 'delete', key); store.data.delete(key); },
      async clear() { store.data.clear(); },
      async flush() { store.flushes++; },
    };
  }
  const preferences = { async getPreferences(_ctx, name) { opens.set(name, (opens.get(name) || 0) + 1); return prefs(name); } };
  const http = { RequestMethod: { GET: 'GET', POST: 'POST' }, createHttp() {
    state.created++; let destroyed = false;
    return {
      async request(url, options) {
        const body = options.extraData ? JSON.parse(options.extraData) : {};
        const request = { url, options, body }; state.requests.push(request); state.active++; state.peak = Math.max(state.peak, state.active);
        try {
          if (state.respond) return await state.respond(request);
          return schoolResponse(request);
        } finally { state.active--; }
      },
      destroy() { assert.equal(destroyed, false, 'HTTP session destroyed twice'); destroyed = true; state.destroyed++; },
    };
  } };
  function load(filename) {
    const full = path.resolve(root, filename);
    if (modules.has(full)) return modules.get(full).exports;
    const module = { exports: {} }; modules.set(full, module);
    const source = fs.readFileSync(full, 'utf8');
    const output = ts.transpileModule(source, { fileName: full.replace(/\.ets$/, '.ts'), compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText;
    const localRequire = spec => {
      if (spec === '@ohos.data.preferences') return { default: preferences };
      if (spec === '@ohos.net.http') return { default: http };
      if (spec === '@ohos.app.ability.ConfigurationConstant') return {default:{ColorMode:{COLOR_MODE_DARK:0,COLOR_MODE_LIGHT:1,COLOR_MODE_NOT_SET:-1}}};
      if (spec === '@ohos.util') return { default: { TextEncoder: class extends TextEncoder {encodeInto(s) {return this.encode(s);}}, TextDecoder: class extends TextDecoder { decodeToString(b) { return this.decode(b); } }, Base64Helper: class {decodeSync(s) {return new Uint8Array(Buffer.from(s,'base64'));}} } };
      if (spec === '@ohos.security.cryptoFramework') return { default: {
        CryptoMode:{DECRYPT_MODE:0},createSymKeyGenerator(algorithm) {assert.equal(algorithm,'SM4_128');return {async convertKey(key){return key;}};},
        createCipher(algorithm) {assert.equal(algorithm,'SM4_128|ECB|PKCS7');let key;return {async init(mode,k,iv){assert.equal(mode,0);assert.equal(iv,null);key=k;},
          async doFinal(input){const c=crypto.createDecipheriv('sm4-ecb',Buffer.from(key.data),null);return {data:new Uint8Array(Buffer.concat([c.update(Buffer.from(input.data)),c.final()]))};}};}
      } };
      if (spec === '@ohos.web.webview') return {default:{WebCookieManager:{clearAllCookiesSync(privateStore){assert.equal(privateStore,true);state.cookieClears=(state.cookieClears||0)+1;}},WebStorage:{deleteAllData(privateStore){assert.equal(privateStore,true);state.storageClears=(state.storageClears||0)+1;}}}};
      if (spec.startsWith('@ohos.') || spec.startsWith('@kit.')) return { default: {} };
      return load(path.relative(root, path.resolve(path.dirname(full), spec + '.ets')));
    };
    const context = vm.createContext({ exports: module.exports, module, require: localRequire, console, Date, Map, Promise,
      AppStorage: { get: key => state[key], set: (key, value) => { state[key] = value; return true; }, setOrCreate: (key, value) => { state[key] = value; return true; } },
      setTimeout: fn => { const id = nextTimer++; timers.set(id, fn); return id; }, clearTimeout: id => timers.delete(id),
    });
    vm.runInContext(output, context, { filename: full });
    return module.exports;
  }
  const cache = load('entry/src/main/ets/services/MemoryCache.ets');
  const auth = load('entry/src/main/ets/services/AuthManager.ets');
  auth.setAuthContext({});
  const api = load('entry/src/main/ets/services/ApiService.ets');
  const todo = load('entry/src/main/ets/services/TodoService.ets'); todo.setTodoContext({});
  const theme = load('entry/src/main/ets/services/ThemeService.ets');
  return { cache, auth, api, todo, theme, state, stores, opens, timers, prefs, load,
    async seedToken() { await auth.saveSchoolSession('student', schoolJwt(), Date.now()+3600000); auth.saveCardToken('fixture-card-token',Date.now()+3600000,cache.getCacheEpoch()); },
    async runTimers() { const callbacks = [...timers.values()]; timers.clear(); callbacks.forEach(fn => fn()); await until(() => stores.get('xjit_http_cache')?.flushes > 0); },
  };
}
const CACHE = 'xjit_http_cache', AUTH = 'xjit_session', TODOS = 'xjit_todos';

test('parallel cache writes reuse preferences and batch disk flush', async () => {
  const f = fixture(); await Promise.all([f.cache.setCachedValue('a', { value: 1 }, 10000), f.cache.setCachedValue('b', { value: 2 }, 10000)]);
  assert.equal(f.opens.get(CACHE), 1); assert.equal(f.stores.get(CACHE).flushes, 0); assert.equal(f.timers.size, 1);
  assert.equal((await f.cache.getCachedValue('a')).value, 1); await f.runTimers(); assert.equal(f.stores.get(CACHE).flushes, 1);
});

test('expired persisted cache is served stale and corrupt entries are purged', async () => {
  const f = fixture(); f.prefs(CACHE); const data = f.stores.get(CACHE).data;
  data.set('expired', JSON.stringify({ value: { lastGood: 1 }, expiresAt: Date.now() - 1 })); data.set('broken', '{broken');
  // Stale-while-revalidate: an expired entry that still holds a last-good value is
  // served so the UI keeps it on screen while ApiService refreshes in the background.
  const expiredValue = await f.cache.getCachedValue('expired');
  assert.equal(expiredValue.lastGood, 1);
  assert.equal(f.cache.isCacheFresh('expired'), false);
  // A corrupt entry is never served and is removed from persistence instead of being re-parsed forever.
  assert.equal(await f.cache.getCachedValue('broken'), null);
  assert.equal(data.has('broken'), false);
});

test('logout invalidates a pending persisted read', async () => {
  const f = fixture(), gate = deferred(); let started = false;
  f.prefs(CACHE); f.stores.get(CACHE).data.set('a', JSON.stringify({ value: { old: true }, expiresAt: Date.now() + 10000 }));
  f.state.hook = async (name, op) => { if (name === CACHE && op === 'get') { started = true; await gate.promise; } };
  const pending = f.cache.getCachedValue('a'); await until(() => started); await f.cache.clearAllCachedValues(); gate.resolve();
  assert.equal(await pending, null); assert.equal(f.stores.get(CACHE).data.size, 0);
});

test('logout clears an in-progress cache write before new session data', async () => {
  const f = fixture(), gate = deferred(); let started = false;
  f.state.hook = async (name, op) => { if (name === CACHE && op === 'put' && !started) { started = true; await gate.promise; } };
  const old = f.cache.setCachedValue('old', { old: true }, 10000); await until(() => started);
  const cleared = f.cache.clearAllCachedValues(); const fresh = f.cache.setCachedValue('new', { fresh: true }, 10000); gate.resolve();
  await Promise.all([old, cleared, fresh]); assert.equal(await f.cache.getCachedValue('old'), null); assert.equal((await f.cache.getCachedValue('new')).fresh, true);
});

test('logout during token persistence cannot resurrect credentials', async () => {
  const f = fixture(), gate = deferred(); let started = false;
  await f.seedToken();
  f.state.hook = async (name, op, key) => { if (name === AUTH && op === 'put' && key === 'access_token' && !started) { started = true; await gate.promise; } };
  const old = f.auth.saveSchoolSession('student', 'old-token', Date.now()+3600000); await until(() => started); const cleared = f.auth.clearSession();
  assert.equal(f.auth.getAccessToken(), ''); assert.equal(f.auth.getUsername(), ''); gate.resolve(); await Promise.all([old, cleared]);
  assert.equal(f.stores.get(AUTH).data.size, 0); assert.equal(f.opens.get(AUTH), 1); assert.equal(await f.auth.loadSession(), false);
  await f.auth.saveSchoolSession('new-student', 'new-token', Date.now()+3600000);
  assert.equal(f.stores.get(AUTH).data.get('access_token'), 'new-token'); assert.equal(f.auth.getUsername(), 'new-student');
});

test('concurrent todo initialization waits for one read and returns independent copies', async () => {
  const f = fixture(), gate = deferred(); let started = false, resolved = false;
  f.prefs(TODOS); f.stores.get(TODOS).data.set('items', JSON.stringify([{ id: '1', title: 'task', note: '', dueText: '', done: false, createdAt: 1, updatedAt: 1 }]));
  f.state.hook = async (name, op) => { if (name === TODOS && op === 'get') { started = true; await gate.promise; } };
  const first = f.todo.loadTodos(); await until(() => started); const second = f.todo.loadTodos().then(v => { resolved = true; return v; });
  await Promise.resolve(); assert.equal(resolved, false); gate.resolve(); const [a, b] = await Promise.all([first, second]);
  assert.equal(a.length, 1); assert.equal(b.length, 1); assert.equal(f.stores.get(TODOS).reads, 1); a[0].title = 'changed'; assert.equal(b[0].title, 'task');
});

test('concurrent feature reads deduplicate; cache hit and manual refresh differ', async () => {
  const f = fixture(); await f.seedToken();
  const [a, b] = await Promise.all([f.api.callFeature('newcard.balance', 'student', 'mock', { b: 2, a: 1 }), f.api.callFeature('newcard.balance', 'student', 'mock', { a: 1, b: 2 })]);
  assert.equal(a.ok, true); assert.equal(b.ok, true); assert.equal(f.state.requests.length, 1);
  const cached = await f.api.callFeature('newcard.balance', 'student', 'mock', { a: 1, b: 2 }); assert.equal(cached.fromCache, true); assert.equal(f.state.requests.length, 1);
  const fresh = await f.api.callFeature('newcard.balance', 'student', 'mock', { _forceRefresh: true, b: 2, a: 1 });
  assert.equal(fresh.fromCache, false); assert.equal(f.state.requests.length, 2); assert.equal('_forceRefresh' in f.state.requests[1].body, false); assert.equal(f.state.created, f.state.destroyed);
});

test('failed school profile and session verification release HTTP sessions and can retry', async () => {
  const f = fixture(); await f.seedToken(); f.state.respond = async () => { throw new Error('mock failure'); };
  assert.equal((await f.api.callFeature('jw.profile', 'student', 'mock', {})).ok, false); assert.equal(f.state.created, f.state.destroyed);
  assert.equal((await f.load('entry/src/main/ets/services/SchoolNativeApi.ets').acceptSchoolLogin(schoolJwt(),f.cache.getCacheEpoch())).ok, false); assert.equal(f.state.created, f.state.destroyed);
  f.state.respond = null; assert.equal((await f.api.callFeature('jw.profile', 'student', 'mock', {})).ok, true);
});

test('prewarm shares ongoing reads, skips valid cache and uses at most two requests', async () => {
  const f = fixture(); await f.seedToken(); await f.api.callFeature('newcard.balance', 'student', 'mock', {}); f.state.requests.length = 0; f.state.peak = 0;
  await Promise.all([f.api.prewarmCampusData('student', 'mock'), f.api.prewarmCampusData('student', 'mock'), f.api.callFeature('jw.profile', 'student', 'mock', {})]);
  assert.deepEqual(f.state.requests.map(r => new URL(r.url).pathname).sort(), ['/personal/api/v1/personal/me/user', '/server/bllt/queryCardSelfTradeList']); assert.ok(f.state.peak <= 2);
  const count = f.state.requests.length; await f.api.prewarmCampusData('student', 'mock'); assert.equal(f.state.requests.length, count);
});

test('background or hidden main page skips the second prewarm stage', async () => {
  for (const key of ['appActive', 'mainPageActive']) {
    const f = fixture(), gate = deferred(); await f.seedToken();
    f.state.respond = async request => { await gate.promise; return schoolResponse(request); };
    const pending = f.api.prewarmCampusData('student', 'mock'); await until(() => f.state.active === 2); f.state[key] = false; gate.resolve(); await pending;
    assert.deepEqual(f.state.requests.map(r => new URL(r.url).pathname).sort(), ['/personal/api/v1/personal/me/user', '/server/user/info']);
  }
});

test('logout rejects a late network response without repopulating cache', async () => {
  const f = fixture(), gate = deferred(); await f.seedToken();
  f.state.respond = async request => { await gate.promise; return schoolResponse(request); };
  const pending = f.api.callFeature('newcard.balance', 'student', 'mock', {}); await until(() => f.state.active === 1);
  await f.auth.clearSession(); gate.resolve(); assert.equal((await pending).ok, false); assert.equal(f.stores.get(CACHE).data.size, 0); assert.equal(f.state.created, f.state.destroyed);
});

test('logout during a 401 token clear prevents reauthentication by the old request', async () => {
  const f = fixture(), gate = deferred(); let started = false; await f.seedToken();
  f.state.respond = async () => ({ responseCode: 401, result: JSON.stringify({ error: 'expired' }) });
  f.state.hook = async (name, op, key) => { if (name === AUTH && op === 'delete' && key === 'access_token' && !started) { started = true; await gate.promise; } };
  const pending = f.api.callFeature('jw.profile', 'student', 'mock', {}); await until(() => started); const cleared = f.auth.clearSession(); gate.resolve();
  const result = await pending; await cleared; assert.equal(result.ok, false); assert.equal(f.state.requests.filter(r => r.url.endsWith('/auth/login')).length, 0); assert.equal(f.auth.getAccessToken(), '');
});


test('prewarm does not start when already backgrounded or hidden', async () => {
  for (const key of ['appActive', 'mainPageActive']) {
    const f = fixture(); await f.seedToken(); f.state[key] = false;
    await f.api.prewarmCampusData('student', 'mock'); assert.equal(f.state.requests.length, 0);
  }
});

test('system theme changes respect the explicit light/dark preference', async () => {
  const f = fixture(); await f.theme.initTheme({}); f.theme.updateSystemTheme(true); assert.equal(f.state.isDark, true);
  await f.theme.setThemeMode('light'); f.theme.updateSystemTheme(true); assert.equal(f.state.isDark, false);
  await f.theme.setThemeMode('dark'); f.theme.updateSystemTheme(false); assert.equal(f.state.isDark, true);
  await f.theme.setThemeMode('system'); assert.equal(f.state.isDark, false);
});

test('native dialogs follow theme only after the window is ready and release the override in system mode',async()=>{
 const f=fixture(),modes=[];await f.theme.initTheme({setColorMode:mode=>modes.push(mode)});await f.theme.setThemeMode('dark');assert.deepEqual(modes,[]);
 f.theme.setNativeThemeReady(true);assert.deepEqual(modes,[0]);f.theme.updateSystemTheme(false);assert.deepEqual(modes,[0]);
 await f.theme.setThemeMode('light');await f.theme.setThemeMode('system');assert.deepEqual(modes,[0,1,-1]);
 f.theme.setNativeThemeReady(false);await f.theme.setThemeMode('dark');assert.deepEqual(modes,[0,1,-1]);f.theme.setNativeThemeReady(true);assert.deepEqual(modes,[0,1,-1,0]);
});
test('late theme restore cannot overwrite a user selection', async () => {
  const f = fixture(), gate = deferred(); let started = false; f.prefs('xjit_theme'); f.stores.get('xjit_theme').data.set('mode', 'light');
  f.state.hook = async (name, op) => { if (name === 'xjit_theme' && op === 'get') { started = true; await gate.promise; } };
  const restore = f.theme.initTheme({}); await until(() => started); await f.theme.setThemeMode('dark'); gate.resolve(); await restore;
  assert.equal(f.state.themeMode, 'dark'); assert.equal(f.state.isDark, true);
});

test('rapid theme choices persist in order with one preferences instance', async () => {
  const f = fixture(), gate = deferred(); let started = false; await f.theme.initTheme({});
  f.state.hook = async (name, op) => { if (name === 'xjit_theme' && op === 'put' && !started) { started = true; await gate.promise; } };
  const first = f.theme.setThemeMode('light'); await until(() => started); const second = f.theme.setThemeMode('dark');
  assert.equal(f.state.isDark, true); gate.resolve(); await Promise.all([first, second]);
  assert.equal(f.stores.get('xjit_theme').data.get('mode'), 'dark'); assert.equal(f.opens.get('xjit_theme'), 1);
});

test('reduced motion restores independently of theme selection', async () => {
  const f = fixture(); f.prefs('xjit_theme'); const data = f.stores.get('xjit_theme').data;
  data.set('reduceMotion', true); data.set('mode', 'dark');
  await f.theme.initTheme({}); assert.equal(f.state.reduceMotion, true); assert.equal(f.state.isDark, true);
  await f.theme.setReduceMotion(false); assert.equal(f.state.reduceMotion, false);
  assert.equal(data.get('reduceMotion'), false); assert.equal(data.get('mode'), 'dark');
});

test('late motion restoration cannot overwrite a user toggle', async () => {
  const f = fixture(), gate = deferred(); let started = false;
  f.prefs('xjit_theme'); f.stores.get('xjit_theme').data.set('reduceMotion', false);
  f.state.hook = async (name, op, key) => { if (name === 'xjit_theme' && op === 'get' && key === 'reduceMotion') { started = true; await gate.promise; } };
  const restore = f.theme.initTheme({}); await until(() => started);
  await f.theme.setReduceMotion(true); gate.resolve(); await restore;
  assert.equal(f.state.reduceMotion, true); assert.equal(f.stores.get('xjit_theme').data.get('reduceMotion'), true);
});

test('rapid motion and theme toggles persist the final choices in order', async () => {
  const f = fixture(), gate = deferred(); let started = false; await f.theme.initTheme({});
  f.state.hook = async (name, op) => { if (name === 'xjit_theme' && op === 'put' && !started) { started = true; await gate.promise; } };
  const first = f.theme.setReduceMotion(true); await until(() => started);
  const second = f.theme.setThemeMode('dark'), third = f.theme.setReduceMotion(false);
  assert.equal(f.state.reduceMotion, false); assert.equal(f.state.isDark, true);
  gate.resolve(); await Promise.all([first, second, third]);
  const data = f.stores.get('xjit_theme').data; assert.equal(data.get('reduceMotion'), false);
  assert.equal(data.get('mode'), 'dark'); assert.equal(f.opens.get('xjit_theme'), 1);
});

test('lazy list snapshot updates notify each mounted listener once', () => {
  const f = fixture(); const { ListDataSource } = f.load('entry/src/main/ets/utils/ListDataSource.ets');
  const rows = new ListDataSource(); let first = 0, second = 0;
  const a = { onDataReloaded() { first++; } }, b = { onDataReloaded() { second++; } };
  rows.registerDataChangeListener(a); rows.registerDataChangeListener(a); rows.registerDataChangeListener(b);
  const input = [{ id: 'one' }, { id: 'two' }]; rows.replace(input); input.push({ id: 'outside' });
  assert.equal(rows.totalCount(), 2); assert.equal(rows.getData(1).id, 'two'); assert.equal(first, 1); assert.equal(second, 1);
  rows.unregisterDataChangeListener(a); rows.unregisterDataChangeListener(a); rows.replace([]);
  assert.equal(rows.totalCount(), 0); assert.equal(first, 1); assert.equal(second, 2);
});


// School-native transport/schema checks. Actual ETS modules, mocked HTTP/OS only.
test('school profile uses the verified HTTPS service and X-Id-Token',async()=>{
 const f=fixture();await f.seedToken();const r=await f.api.callFeature('jw.profile','student','unused',{});assert.equal(r.ok,true);assert.equal(r.data.studentId,'student');
 const q=f.state.requests[0];assert.equal(q.url,'https://authx-service.xjit.edu.cn/personal/api/v1/personal/me/user');assert.equal(q.options.method,'GET');assert.equal(q.options.header['X-Id-Token'],f.auth.getAccessToken());assert.equal(q.options.header.Authorization,undefined);assert.equal(q.options.usingCache,false);assert.deepEqual(q.body,{});
});
test('school card uses its own authorization and native amount mapping',async()=>{
 const f=fixture();await f.seedToken();const r=await f.api.callFeature('newcard.balance','student','unused',{});assert.equal(r.ok,true);assert.equal(r.data.accounts[0].balance,'12.34');
 const q=f.state.requests[0];assert.equal(q.url,'https://newcard.xjit.edu.cn/server/user/info');assert.equal(q.options.method,'POST');assert.equal(q.options.header.Authorization,'fixture-card-token');assert.equal(q.options.header['X-Id-Token'],undefined);assert.deepEqual(q.body,{});
});
test('school transactions use verified parameters and convert minor units',async()=>{
 const f=fixture();await f.seedToken();const r=await f.api.callFeature('newcard.transactions','student','unused',{fromDate:'2026-10-01',toDate:'2026-10-09',pageNo:2});assert.equal(r.ok,true);assert.equal(r.data.transactions[0].amount,'6.50');
 assert.equal(f.state.requests[0].url,'https://newcard.xjit.edu.cn/server/bllt/queryCardSelfTradeList');assert.deepEqual(f.state.requests[0].body,{starttime:'2026-10-01',endtime:'2026-10-09',tradetype:'-1',pageNumber:1,pageSize:20});
});
test('invalid native dates and page numbers cause no HTTP request',async()=>{
 for(const params of [{fromDate:'2026-02-30'},{fromDate:'2026-10-10',toDate:'2026-10-09'},{pageNo:-1},{pageNo:1.5},{pageNo:'bad'}]){const f=fixture();await f.seedToken();assert.equal((await f.api.callFeature('newcard.transactions','student','unused',params)).ok,false);assert.equal(f.state.requests.length,0);}
});
test('legacy migration clears old account data and does not forward it',async()=>{
 const f=fixture();f.prefs(AUTH);const old=f.stores.get(AUTH).data;old.set('username','legacy');old.set('access_token','legacy');await f.cache.setCachedValue('legacy',{private:'old'},10000);
 assert.equal(await f.auth.loadSession(),false);assert.equal(old.size,0);assert.equal(await f.cache.getCachedValue('legacy'),null);assert.equal(f.auth.getAccessToken(),'');assert.equal(f.state.requests.length,0);
});
test('JWT expiry rejects invalid sessions before contacting school',async()=>{
 for(const token of ['invalid','a.bad.a',schoolJwt(1)]){const f=fixture();const n=f.load('entry/src/main/ets/services/SchoolNativeApi.ets');assert.equal((await n.acceptSchoolLogin(token,f.cache.getCacheEpoch())).ok,false);assert.equal(f.state.requests.length,0);assert.equal(f.auth.getUsername(),'');}
});
test('school profile verification is required before a session is saved',async()=>{
 const f=fixture(),n=f.load('entry/src/main/ets/services/SchoolNativeApi.ets');f.state.respond=async()=>({responseCode:200,result:JSON.stringify({code:1,data:{}})});assert.equal((await n.acceptSchoolLogin(schoolJwt(),f.cache.getCacheEpoch())).ok,false);assert.equal(f.auth.getAccessToken(),'');
 f.state.respond=null;assert.equal((await n.acceptSchoolLogin(schoolJwt(),f.cache.getCacheEpoch())).ok,true);assert.equal(f.stores.get(AUTH).data.get('protocol'),'school-native-v1');assert.equal(f.auth.getUsername(),'student');
});
test('failed persistence is not reported as successful school login',async()=>{
 const f=fixture();f.state.hook=async(name,op,key)=>{if(name===AUTH&&op==='put'&&key==='access_token')throw Error('disk unavailable');};const n=f.load('entry/src/main/ets/services/SchoolNativeApi.ets');assert.equal((await n.acceptSchoolLogin(schoolJwt(),f.cache.getCacheEpoch())).ok,false);assert.equal(f.auth.getAccessToken(),'');
});
test('logout rejects late school login verification',async()=>{
 const f=fixture(),g=deferred();f.state.respond=async q=>{await g.promise;return schoolResponse(q);};const n=f.load('entry/src/main/ets/services/SchoolNativeApi.ets'),pending=n.acceptSchoolLogin(schoolJwt(),f.cache.getCacheEpoch());await until(()=>f.state.active===1);await f.auth.clearSession();g.resolve();assert.equal((await pending).ok,false);assert.equal(f.auth.getUsername(),'');
});
test('card session needs native verification and a live owner',async()=>{
 const f=fixture();await f.seedToken();f.auth.clearCardToken();const n=f.load('entry/src/main/ets/services/SchoolNativeApi.ets');assert.equal((await n.acceptSchoolCardLogin('new-card',Date.now()+3600000,f.cache.getCacheEpoch(),'different-owner')).ok,false);assert.equal(f.state.requests.length,0);
 assert.equal((await n.acceptSchoolCardLogin('new-card',Date.now()+3600000,f.cache.getCacheEpoch(),'student')).ok,true);assert.equal(f.auth.getCardToken(),'new-card');
});
test('card credential changes prevent reuse of old cache and late results',async()=>{
 const f=fixture();await f.seedToken();await f.api.callFeature('newcard.balance','student','unused',{});f.auth.clearCardToken();assert.equal((await f.api.callFeature('newcard.balance','student','unused',{})).ok,false);f.auth.saveCardToken('new-card',Date.now()+3600000,f.cache.getCacheEpoch());assert.equal((await f.api.callFeature('newcard.balance','student','unused',{})).fromCache,false);assert.equal(f.state.requests.length,2);
 const g=deferred();f.state.respond=async q=>{await g.promise;return schoolResponse(q);};const pending=f.api.callFeature('newcard.balance','student','unused',{_forceRefresh:true});await until(()=>f.state.active===1);f.auth.saveCardToken('another-card',Date.now()+3600000,f.cache.getCacheEpoch());g.resolve();assert.equal((await pending).ok,false);
});
test('wrong portal account cannot read cached personal information',async()=>{
 const f=fixture();await f.seedToken();await f.api.callFeature('jw.profile','student','unused',{});assert.equal((await f.api.callFeature('jw.profile','another','unused',{})).ok,false);assert.equal(f.state.requests.length,1);
});
test('late card 401 cannot invalidate a newer card connection',async()=>{
 const f=fixture(),g=deferred();await f.seedToken();f.state.respond=async()=>{await g.promise;return{responseCode:401,result:'{}'};};const p=f.api.callFeature('newcard.balance','student','unused',{});await until(()=>f.state.active===1);f.auth.saveCardToken('new-card',Date.now()+3600000,f.cache.getCacheEpoch());g.resolve();await p;assert.equal(f.auth.getCardToken(),'new-card');assert.notEqual(f.auth.getAccessToken(),'');
});
test('school SM4 envelope decrypts with actual CryptoUtil and an OS provider mock',async()=>{
 const f=fixture();const text=JSON.stringify({success:true,resultData:{user:{balance:'19.87'}}});const c=crypto.createCipheriv('sm4-ecb',Buffer.from('w687-9+3C_H&je_5'),null);const encoded=Buffer.concat([c.update(text),c.final()]).toString('base64');
 assert.equal(await f.load('entry/src/main/ets/utils/CryptoUtil.ets').decryptSchoolCardEnvelope(encoded),text);await f.seedToken();f.state.respond=async()=>({responseCode:200,result:JSON.stringify({success:false,data:encoded})});assert.equal((await f.api.callFeature('newcard.balance','student','unused',{})).data.accounts[0].balance,'19.87');
});
test('malformed native response and ciphertext always release HTTP sessions',async()=>{
 for(const result of ['{broken',JSON.stringify({ok:true,data:{}}),JSON.stringify({success:false,data:'invalid'}),JSON.stringify({success:true,resultData:[]})]){const f=fixture();await f.seedToken();f.state.respond=async()=>({responseCode:200,result});assert.equal((await f.api.callFeature('newcard.balance','student','unused',{})).ok,false);assert.equal(f.state.created,f.state.destroyed);}
});
test('native schemas reject invalid amounts and missing transaction arrays',()=>{
 const n=fixture().load('entry/src/main/ets/services/SchoolNativeApi.ets');for(const balance of [null,'','bad',{},'NaN'])assert.throws(()=>n.normalizeSchoolBalance({user:{balance}}));assert.throws(()=>n.normalizeSchoolTransactions({rows:null,totalpage:1},{}));assert.throws(()=>n.normalizeSchoolTransactions({rows:[{txamt:null}],totalpage:1},{}));assert.throws(()=>n.normalizeSchoolTransactions({rows:[]},{}));
});
test('unimplemented school features cannot send guessed requests or retry payments',async()=>{
 const f=fixture();await f.seedToken();for(const feature of ['jw.schedule','jw.grades','jw.exams','jw.training','newcard.campus_code.qrcode','newcard.recharge.config','newcard.recharge.create_order','newcard.electricity.account','newcard.electricity.recharge.config','newcard.electricity.recharge.pay']){const r=await f.api.callFeature(feature,'student','unused',{});assert.equal(r.ok,false);assert.equal(r.statusCode,501);}assert.equal(f.state.requests.length,0);
});
test('logout clears private school storage and increments card generation',async()=>{
 const f=fixture();await f.seedToken();const epoch=f.auth.getCardSessionEpoch();await f.auth.clearSession();assert.equal(f.auth.getCardToken(),'');assert.ok(f.auth.getCardSessionEpoch()>epoch);assert.equal(f.state.cookieClears,1);assert.equal(f.state.storageClears,1);
});

module.exports = {fixture,deferred,until,schoolJwt,schoolResponse};
if (require.main === module) (async () => {
  let failed = 0;
  for (const t of tests) { try { await t.run(); console.log('PASS ' + t.name); } catch (error) { failed++; console.error('FAIL ' + t.name); console.error(error.stack); } }
  console.log(tests.length + ' checks, ' + failed + ' failed'); process.exitCode = failed ? 1 : 0;
})();
