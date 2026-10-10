'use strict';
// Runs the actual non-rendering page methods with mocked API, clock and timers.
// ArkUI build/builder bodies are deliberately excluded; device UI is checked separately.
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const tsPath = process.env.XJIT_TYPESCRIPT_PATH || 'D:/data/devecostudionext/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js';
if (!fs.existsSync(tsPath)) throw new Error('Existing TypeScript SDK missing; no download attempted.');
const ts = require(tsPath), tests = [];
function test(name, run) { tests.push({ name, run }); }
function gate() { let resolve, reject; const promise = new Promise((r, j) => { resolve = r; reject = j; }); return { promise, resolve, reject }; }
async function until(predicate) { for (let i = 0; i < 300; i++) { if (predicate()) return; await Promise.resolve(); } throw new Error('Asynchronous checkpoint missing'); }
function fixture(name) {
  const state = { epoch: 1, cardEpoch: 1, username: 'sample-student', now: 100000, requests: [], timers: new Map(), nextTimer: 1, toasts: [] };
  let rowsModule = { exports: {} };
  const rows = fs.readFileSync(path.join(root, 'entry/src/main/ets/utils/ListDataSource.ets'), 'utf8');
  vm.runInNewContext(ts.transpileModule(rows, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText, { exports: rowsModule.exports, module: rowsModule });
  let source = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/' + name + '.ets'), 'utf8').replace(/\r\n/g, '\n');
  const bodyEnd = source.search(/  (?:@Builder|build\(\))/);
  if (bodyEnd < 0) throw new Error('Page logic boundary missing: ' + name);
  source = source.slice(0, bodyEnd) + '\n}\n';
  source = source.replace(/@(?:Entry|Component)\s*/g, '').replace(/@(?:StorageLink|Watch)\([^)]*\)\s*/g, '').replace(/@State\s*/g, '')
    .replace('struct ' + name, 'export class ' + name);
  const module = { exports: {} };
  const context = {
    exports: module.exports, module, console, Date: class extends Date { static now() { return state.now; } },
    setTimeout(fn, delay) { const id = state.nextTimer++; state.timers.set(id, { fn, delay, interval: false }); return id; },
    setInterval(fn, delay) { const id = state.nextTimer++; state.timers.set(id, { fn, delay, interval: true }); return id; },
    clearTimeout(id) { state.timers.delete(id); }, clearInterval(id) { state.timers.delete(id); },
    require(spec) {
      if (spec.endsWith('/ApiService')) return { callFeature(feature, username, password, params) { const deferred = gate(); state.requests.push({ feature, username, params, ...deferred }); return deferred.promise; } };
      if (spec.endsWith('/AuthManager')) return { getUsername: () => state.username, getPassword: () => 'mock', getCardSessionEpoch: () => state.cardEpoch, getCardAccountLabel: () => '测试校园卡' };
      if (spec.endsWith('/MemoryCache')) return { getCacheEpoch: () => state.epoch };
      if (spec.endsWith('/ListDataSource')) return rowsModule.exports;
      if (spec.endsWith('/RouterHelper')) return { safeBack() {} };
      if (spec.endsWith('/ToastHelper')) return { safeToast(_ctx, text) { state.toasts.push(text); } };
      if (spec === '@ohos.web.webview') return { default: { WebviewController: class {} } };
      if (spec === '@ohos.util') return { default: {} };
      return {};
    },
  };
  vm.runInNewContext(ts.transpileModule(source, { fileName: name + '.ts', compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText, context);
  const page = new module.exports[name](); page.getUIContext = () => ({});
  return { page, state };
}
const queries = [
  ['TransactionsPage', 'transactions', 'items'], ['GradesPage', 'normalGrades', 'grades'], ['ExamsPage', 'exams', 'exams'],
  ['BalancePage', 'accounts', 'accounts'], ['TrainingPage', 'training', 'items'], ['SchedulePage', 'courses', 'courses'],
  ['ProfilePage', 'name', 'name'],
];
function success(key, marker) { return { ok: true, data: { [key]: key === 'name' ? marker : [{ marker }], summary: { weightedGradePoint: 3.8, totalCredits: 6, failedCourseCount: 0 } } }; }
for (const [name, key, field] of queries) {
  test(name + ' keeps successful content on failed refresh and deduplicates taps', async () => {
    const { page, state } = fixture(name); page.alive = true;
    const first = page.load(); state.requests[0].resolve(success(key, 'kept')); await first;
    const kept = page[field], refresh = page.load(true); await page.load(true);
    assert.equal(state.requests.length, 2); assert.equal(state.requests[1].params._forceRefresh, true);
    state.requests[1].resolve({ ok: false, error: 'offline' }); await refresh;
    assert.equal(page.loaded, true); assert.equal(page[field], kept); assert.equal(page.errorMsg, 'offline'); assert.equal(page.loading, false);
  });
  test(name + ' ignores an old response after disappear and resumes loading on reappear', async () => {
    const { page, state } = fixture(name); page.alive = true;
    const old = page.load(); page.aboutToDisappear(); assert.equal(page.loading, false); page.aboutToAppear();
    assert.equal(state.requests.length, 2); state.requests[0].resolve(success(key, 'old')); await old;
    assert.equal(page.loaded, false); assert.equal(page.loading, true);
    state.requests[1].resolve(success(key, 'new')); await until(() => page.loaded);
    assert.equal(field === 'name' ? page[field] : page[field][0].marker, 'new'); assert.equal(page.loading, false);
  });
  test(name + ' rejects responses after logout or account change', async () => {
    for (const change of ['epoch', 'username']) {
      const { page, state } = fixture(name); page.alive = true; const pending = page.load();
      if (change === 'epoch') state.epoch++; else state.username = 'another-student';
      state.requests[0].resolve(success(key, 'old-session')); await pending;
      assert.equal(page.loaded, false); assert.equal(page.loading, false);
    }
  });
  test(name + ' clears busy state on request exception', async () => {
    const { page, state } = fixture(name); page.alive = true; const pending = page.load();
    state.requests[0].reject(new Error('mock offline')); await pending;
    assert.equal(page.loading, false); assert.ok(page.errorMsg.length > 0);
  });
}
test('grade summary does not present missing or nonfinite values as zero', async () => {
  const { page, state } = fixture('GradesPage'); page.alive = true; const pending = page.load();
  state.requests[0].resolve({ ok: true, data: { normalGrades: [], summary: { weightedGradePoint: NaN, totalCredits: Infinity } } }); await pending;
  assert.equal(page.gpa, '—'); assert.equal(page.credits, '—'); assert.equal(page.failedCount, '—');
});
test('recharge configuration retry resets unavailable selected options', async () => {
  const { page, state } = fixture('RechargePage'); page.alive = true; page.selectedAmount = '100'; page.selectedPayCode = 'old';
  const pending = page.loadConfig(true); state.requests[0].resolve({ ok: true, data: { balance: '12.00', amountOptions: [{ id: '1', amount: '50', name: '50元' }], payMethods: [{ code: '06', name: '示例' }] } }); await pending;
  assert.equal(page.loading, false); assert.equal(page.selectedAmount, ''); assert.equal(page.selectedPayCode, '');
});
test('recharge explicit payment deduplicates and rejects late account results', async () => {
  const { page, state } = fixture('RechargePage'); page.alive = true; page.loading = false; page.selectedAmount = '50'; page.selectedPayCode = '06';
  const pending = page.handlePay(); await page.handlePay(); assert.equal(state.requests.length, 1); state.epoch++;
  state.requests[0].resolve({ ok: true, data: { payResult: { h5Url: 'https://mock.invalid' } } }); await pending;
  assert.equal(page.step, 1); assert.equal(page.payContent, ''); assert.equal(page.paying, false);
});
test('electricity back prevents a late query from advancing the step', async () => {
  const { page, state } = fixture('ElectricityPage'); page.alive = true; page.roomQuery = ' 1-101 ';
  const pending = page.queryElectricity(); assert.equal(state.requests[0].params.roomQuery, '1-101'); page.back();
  state.requests[0].resolve({ ok: true, data: { marker: 'old' } }); await pending;
  assert.equal(page.step, 1); assert.equal(page.electricity, null); assert.equal(page.loading, false);
});
test('electricity payment cannot submit twice or navigate to a duplicate order', async () => {
  const { page, state } = fixture('ElectricityPage'); page.alive = true; page.step = 3; page.selectedAmount = '50';
  const pending = page.handlePay(); await page.handlePay(); page.back();
  assert.equal(state.requests.length, 1); assert.equal(page.step, 3);
  state.requests[0].resolve({ ok: false, error: 'offline' }); await pending;
  assert.equal(page.paying, false); assert.equal(page.errorMsg, 'offline');
});
test('QR background stops timers and clears expired code before resumed request', async () => {
  const { page, state } = fixture('QRCodePage'); page.alive = true;
  const pending = page.fetchCode(); state.requests[0].resolve({ ok: true, data: { qrcode: 'sample-only', expiresInSeconds: 30 } }); await pending;
  assert.equal(state.timers.size, 2); page.appActive = false; page.onAppActiveChange(); assert.equal(state.timers.size, 0);
  await page.fetchCode(); assert.equal(state.requests.length, 1); state.now += 31000;
  page.appActive = true; page.onAppActiveChange(); assert.equal(page.qrcode, ''); assert.equal(state.requests.length, 2);
  state.requests[1].resolve({ ok: false, error: 'offline' }); await until(() => !page.requestBusy);
  assert.equal(state.timers.size, 0); assert.equal(page.qrcode, '');
});
test('QR response while hidden cannot restart timers', async () => {
  const { page, state } = fixture('QRCodePage'); page.alive = true;
  const pending = page.fetchCode(); page.onPageHide(); state.requests[0].resolve({ ok: true, data: { qrcode: 'sample-only', expiresInSeconds: 30 } }); await pending;
  assert.equal(state.timers.size, 0); assert.equal(page.loading, false);
});
test('QR expiry interval removes a stale code even when refresh fails', async () => {
  const { page, state } = fixture('QRCodePage'); page.alive = true;
  const pending = page.fetchCode(); state.requests[0].resolve({ ok: true, data: { qrcode: 'sample-only', expiresInSeconds: 1 } }); await pending;
  state.now += 1100; [...state.timers.values()].find(t => t.interval).fn(); assert.equal(page.qrcode, ''); assert.equal(page.countdown, 0);
});
test('QR request exception clears loading and offers an error state', async () => {
  const { page, state } = fixture('QRCodePage'); page.alive = true;
  const pending = page.fetchCode(); state.requests[0].reject(new Error('offline')); await pending;
  assert.equal(page.loading, false); assert.equal(page.requestBusy, false); assert.ok(page.errorMsg.length > 0); assert.equal(state.timers.size, 0);
});

test('native transactions append successive school pages without duplicate requests', async () => {
  const {page,state}=fixture('TransactionsPage'); page.alive=true;
  let pending=page.load(); assert.equal(state.requests[0].params.pageNo,1);
  state.requests[0].resolve({ok:true,data:{transactions:[{journo:'one'}],pageNo:1,totalPages:3}}); await pending;
  pending=page.load(false,true); await page.load(false,true);
  assert.equal(state.requests.length,2); assert.equal(state.requests[1].params.pageNo,2);
  state.requests[1].resolve({ok:true,data:{transactions:[{journo:'two'}],pageNo:2,totalPages:3}}); await pending;
  assert.deepEqual(Array.from(page.items,x=>x.journo),['one','two']); assert.equal(page.nextPage,3);
  pending=page.load(false,true); assert.equal(state.requests[2].params.pageNo,3);
  state.requests[2].resolve({ok:true,data:{transactions:[{journo:'three'}],pageNo:3,totalPages:3}}); await pending;
  assert.equal(page.items.length,3); assert.equal(page.nextPage,4); assert.equal(page.rows.totalCount(),3);
});
test('native transactions retry a failed page and replace rows on refresh', async () => {
  const {page,state}=fixture('TransactionsPage'); page.alive=true;
  let pending=page.load(); state.requests[0].resolve({ok:true,data:{transactions:[{journo:'old'}],pageNo:1,totalPages:2}}); await pending;
  pending=page.load(false,true); state.requests[1].resolve({ok:false,error:'page unavailable'}); await pending;
  assert.equal(page.items.length,1); assert.equal(page.nextPage,2); assert.equal(page.loaded,true);
  pending=page.load(false,true); assert.equal(state.requests[2].params.pageNo,2);
  state.requests[2].resolve({ok:true,data:{transactions:[{journo:'second'}],pageNo:2,totalPages:2}}); await pending;
  pending=page.load(true); assert.equal(state.requests[3].params.pageNo,1);
  state.requests[3].resolve({ok:true,data:{transactions:[{journo:'new'}],pageNo:1,totalPages:1}}); await pending;
  assert.deepEqual(Array.from(page.items,x=>x.journo),['new']); assert.equal(page.nextPage,2); assert.equal(page.totalPages,1);
});
for(const [name,key,field] of [['BalancePage','accounts','accounts'],['TransactionsPage','transactions','items']]) {
  test(name+' rejects a late result when only the card session changes',async()=>{
    const {page,state}=fixture(name); page.alive=true;
    let pending=page.load(); state.requests[0].resolve(success(key,'old card')); await pending;
    pending=page.load(true); state.cardEpoch++;
    state.requests[1].resolve(success(key,'retired card')); await pending;
    assert.equal(page.loaded,false); assert.equal(page[field].length,0); assert.equal(page.cardAccount,''); assert.equal(page.errorMsg,''); assert.equal(page.loading,false);
    pending=page.load(); state.requests[2].resolve(success(key,'current card')); await pending;
    assert.equal(page.loaded,true); assert.equal(page[field][0].marker,'current card');
  });
  test(name+' ignores a request exception from a retired card session',async()=>{
    const {page,state}=fixture(name); page.alive=true;
    const pending=page.load(); state.cardEpoch++; state.requests[0].reject(new Error('retired request')); await pending;
    assert.equal(page.loaded,false); assert.equal(page[field].length,0); assert.equal(page.errorMsg,''); assert.equal(page.loading,false);
  });
}

(async () => {
  let failed = 0;
  for (const t of tests) { try { await t.run(); console.log('PASS ' + t.name); } catch (error) { failed++; console.error('FAIL ' + t.name); console.error(error.stack); } }
  console.log(tests.length + ' page behavior checks, ' + failed + ' failed'); process.exitCode = failed ? 1 : 0;
})();
