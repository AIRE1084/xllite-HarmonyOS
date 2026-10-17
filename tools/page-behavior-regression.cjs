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
  source = source.replace(/@(?:Entry|Component)\s*/g, '').replace(/@(?:StorageLink|Watch)\([^)]*\)\s*/g, '').replace(/@State\s*/g, '').replace(/@Prop\s*/g, '')
    .replace('export struct ' + name, 'struct ' + name).replace('struct ' + name, 'export class ' + name);
  const module = { exports: {} };
  const context = {
    AppStorage: { get:()=>7, setOrCreate(){} },
    exports: module.exports, module, console, Date: class extends Date { static now() { return state.now; } },
    setTimeout(fn, delay) { const id = state.nextTimer++; state.timers.set(id, { fn, delay, interval: false }); return id; },
    setInterval(fn, delay) { const id = state.nextTimer++; state.timers.set(id, { fn, delay, interval: true }); return id; },
    clearTimeout(id) { state.timers.delete(id); }, clearInterval(id) { state.timers.delete(id); },
    require(spec) {
      if (spec.endsWith('/ApiService')) return { callFeature(feature, username, password, params) { const deferred = gate(); state.requests.push({ feature, username, params, ...deferred }); return deferred.promise; } };
      if (spec.endsWith('/AuthManager')) return { getUsername: () => state.username, loadElectricityRoom: async () => state.roomLoad ? await state.roomLoad : state.room || '', saveElectricityRoom: async value => { state.room = value; }, getPassword: () => 'mock', getCardSessionEpoch: () => state.cardEpoch, getCardAccountLabel: () => '测试校园卡' };
      if (spec.endsWith('/TodoService')) return {async addTodo(draft){state.todoAdds=(state.todoAdds||0)+1;if(state.todoPending)await state.todoPending;return []},toggleTodo:async()=>{if(state.todoActionPending)return await state.todoActionPending;throw new Error('fixture disk failure')},deleteTodo:async()=>{if(state.todoActionPending)return await state.todoActionPending;throw new Error('fixture disk failure')},disableTodoReminders:async()=>{state.todoDisabled=true},registerTodoReminders:async()=>{state.todoRegisters=(state.todoRegisters||0)+1;return 2},getTodoReminderStatus:()=> 'fixture status',restoreTodoReminderStatus:async()=>{state.todoRestores=(state.todoRestores||0)+1},refreshTodoWidgets:async()=>{state.todoRefreshes=(state.todoRefreshes||0)+1},loadTodos:async()=>state.todoLoad?await state.todoLoad:[],countOpenTodos:()=>0};
      if (spec.endsWith('/Colors')) return {getColors:()=>({})};
      if (spec.endsWith('/MemoryCache')) return { getCacheEpoch: () => state.epoch };
      if (spec.endsWith('/SemesterService')) return {getTerm:()=> 'fixture-term'};
      if (spec.endsWith('/UiStateCache')) return { loadUiState() { return state.savedUi || null; }, saveUiState() {}, clearUiState() {} };
      if (spec.endsWith('/ListDataSource')) return rowsModule.exports;
      if (spec.endsWith('/RouterHelper')) return { safeBack() {} };
      if (spec.endsWith('/ToastHelper')) return { safeToast(_ctx, text) { state.toasts.push(text); } };
      if (spec === '@ohos.notificationManager') return {default:{isNotificationEnabled:async()=>true,requestEnableNotification:async()=>{}}};
      if (spec === '@ohos.web.webview') return { default: { WebviewController: class {} } };
      if (spec === '@ohos.util') return { default: {} };
      return {};
    },
  };
  vm.runInNewContext(ts.transpileModule(source, { fileName: name + '.ts', compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText, context);
  const page = new module.exports[name](); page.getUIContext = () => ({}); if(name==='TodoPage')page.alive=true;
  return { page, state };
}
test('electricity restores saved room and queries without rebinding',async()=>{
 const {page,state}=fixture('ElectricityPage');state.room='9#312';
 const task=page.aboutToAppear();for(let i=0;i<20&&state.requests.length===0;i++)await Promise.resolve();
 assert.equal(state.requests.length,1);assert.equal(state.requests[0].params.roomQuery,'9#312');
 state.requests[0].resolve({ok:true,data:{}});await task;assert.equal(page.step,2);
});
test('electricity successful query remembers room while failed query preserves binding',async()=>{
 const {page,state}=fixture('ElectricityPage');page.alive=true;page.roomQuery=' 9#312 ';
 const task=page.queryElectricity();state.requests[0].resolve({ok:true,data:{}});await task;assert.equal(state.room,'9#312');
 page.roomQuery='3#312';const fail=page.queryElectricity();state.requests[1].resolve({ok:false,error:'fixture'});await fail;assert.equal(state.room,'9#312');
});
test('electricity change room retires requests and keeps stored binding until success',()=>{
 const {page,state}=fixture('ElectricityPage');page.alive=true;page.step=2;page.electricity={};state.room='9#312';
 const version=page.requestVersion;page.changeRoom();assert.equal(page.step,1);assert.equal(page.electricity,null);assert.ok(page.requestVersion>version);assert.equal(state.room,'9#312');
 page.paying=true;page.step=3;page.changeRoom();assert.equal(page.step,3);
});
test('electricity results offer refresh independently from change room',()=>{
 const source=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/ElectricityPage.ets'),'utf8');
 assert.match(source,/Button\(this.loading \? '刷新中…' : '刷新电量'\)/);assert.match(source,/Button\('更换宿舍'\)/);
});
test('electricity restore errors from a retired account do not alter the page',async()=>{
 const {page,state}=fixture('ElectricityPage');let reject;
 state.roomLoad=new Promise((_resolve,r)=>{reject=r});const task=page.aboutToAppear();
 state.epoch++;state.username='other-account';reject(new Error('fixture read failure'));await task;
 assert.equal(page.errorMsg,'');assert.equal(state.requests.length,0);
});
test('todo explicit time accepts future only and can be cleared',()=>{
 const {page,state}=fixture('TodoPage');const date=new Date(2026,9,18);
 page.selectDueTime(date,20,0);assert.equal(page.dueAt,new Date(2026,9,18,20,0).getTime());assert.ok(page.dueInput.includes('20:00'));
 const prior=page.dueAt;page.selectDueTime(date,24,0);assert.equal(page.dueAt,prior);
 page.selectDueTime(new Date(1970,0,1),0,0);assert.equal(page.dueAt,prior);
 page.clearDueTime();assert.equal(page.dueAt,undefined);assert.equal(page.dueInput,'');
});
test('todo add revalidates time and deduplicates pending submission',async()=>{
 const {page,state}=fixture('TodoPage');page.titleInput='Study';page.dueAt=state.now;await page.handleAdd();assert.equal(state.todoAdds||0,0);
 page.dueAt=state.now+60000;let resolve;state.todoPending=new Promise(r=>resolve=r);const first=page.handleAdd();await page.handleAdd();assert.equal(state.todoAdds,1);resolve();await first;assert.equal(page.saving,false);
});
test('todo add failure preserves input and unlocks retry',async()=>{
 const {page,state}=fixture('TodoPage');page.titleInput='Study';state.todoPending=Promise.reject(new Error('fixture'));
 await page.handleAdd();assert.equal(page.titleInput,'Study');assert.equal(page.saving,false);assert.ok(state.toasts.length>0);
});
test('todo toggle and delete errors retain visible rows and report retry',async()=>{
 const {page,state}=fixture('TodoPage');const item={id:'fixture',title:'Study'};page.todos=[item];
 await page.handleToggle(item);assert.equal(page.todos[0],item);assert.equal(state.toasts.length,1);
 await page.handleDelete(item);assert.equal(page.todos[0],item);assert.equal(state.toasts.length,2);
});
test('todo explicit reminder action reports actual registration count',async()=>{
 const {page,state}=fixture('TodoPage');await page.handleReminders();assert.equal(state.todoRegisters,1);assert.ok(state.toasts.at(-1).includes('2'));assert.equal(page.reminderBusy,false);
});
test('todo reminder cancellation reports success and unlocks controls',async()=>{
 const {page,state}=fixture('TodoPage');await page.handleDisableReminders();assert.equal(state.todoDisabled,true);assert.equal(page.reminderBusy,false);assert.ok(state.toasts.at(-1).includes('已取消'));
});
test('todo initial load ignores results after disappearance or account change',async()=>{
 for(const mode of ['disappear','account']){
  const {page,state}=fixture('TodoPage');let resolve;state.todoLoad=new Promise(r=>resolve=r);const task=page.aboutToAppear();
  if(mode==='disappear')page.aboutToDisappear();else{state.epoch++;state.username='other'}
  resolve([{id:'old',title:'Private'}]);await task;assert.equal(page.todos.length,0);assert.equal(state.todoRestores||0,0);assert.equal(state.todoRefreshes||0,0);
 }
});
test('todo add completion does not clear form after page disappearance',async()=>{
 const {page,state}=fixture('TodoPage');page.alive=true;page.titleInput='Study';let resolve;state.todoPending=new Promise(r=>resolve=r);
 const task=page.handleAdd();page.aboutToDisappear();resolve();await task;assert.equal(page.titleInput,'Study');assert.equal(state.toasts.length,0);
});
test('todo toggle delete callbacks ignore retired pages and accounts',async()=>{
 for(const method of ['handleToggle','handleDelete'])for(const mode of ['disappear','account']){
  const {page,state}=fixture('TodoPage');const old={id:'old',title:'Study'};page.todos=[old];let resolve;
  state.todoActionPending=new Promise(r=>resolve=r);const task=page[method](old);
  if(mode==='disappear')page.aboutToDisappear();else{state.epoch++;state.username='other'}
  resolve([]);await task;assert.equal(page.todos[0],old);assert.equal(state.toasts.length,0);
 }
});
test('schedule restoration ignores fractional nonfinite and out-of-term weeks',()=>{
 for(const week of [1.5,NaN,Infinity,-1,0,21,999]){
  const f=fixture('ScheduleTab');f.page.currentWeek=7;f.page.totalWeeks=20;
  f.state.savedUi={selectedWeek:week};f.page.onActivityChange=()=>{};
  f.page.aboutToAppear();assert.equal(f.page.selectedWeek,7);assert.equal(f.page.restoredWeek,0);
 }
 const f=fixture('ScheduleTab');f.state.savedUi={selectedWeek:12};f.page.onActivityChange=()=>{};
 f.page.aboutToAppear();assert.equal(f.page.selectedWeek,12);assert.equal(f.page.restoredWeek,12);
});
test('schedule ignores invalid total weeks instead of truncating or accepting infinity',async()=>{
 for(const totalWeeks of [Infinity,NaN,0,-1,0.5,1.5,61,999]){
  const f=fixture('ScheduleTab');f.page.alive=true;f.page.totalWeeks=20;f.page.updateDerived=()=>{};
  const task=f.page.loadSchedule(false);await until(()=>f.state.requests.length===1);
  f.state.requests[0].resolve({ok:true,data:{courses:[],totalWeeks}});await task;
  assert.equal(f.page.totalWeeks,20);assert.equal(f.page.hasLoaded,true);assert.equal(f.page.errorMsg,'');
 }
});
test('valid semester bounds and alternate field keep selected week inside semester',async()=>{
 for(const [data,expected] of [[{totalWeeks:1},1],[{totalWeeks:60},60],[{totalWeeks:Infinity,weeksTotal:19},19]]){
  const f=fixture('ScheduleTab');f.page.alive=true;f.page.updateDerived=()=>{};
  const task=f.page.loadSchedule(false);await until(()=>f.state.requests.length===1);
  f.state.requests[0].resolve({ok:true,data:{courses:[],...data}});await task;
  assert.equal(f.page.totalWeeks,expected);assert.equal(f.page.hasLoaded,true);
  assert.ok(f.page.selectedWeek>=1&&f.page.selectedWeek<=expected);
 }
});
test('schedule tab handles thrown request and permits retry',async()=>{
 const f=fixture('ScheduleTab'); f.page.alive=true;
 const task=f.page.loadSchedule(false); await until(()=>f.state.requests.length===1);
 f.state.requests[0].reject(Error('transport')); await task;
 assert.equal(f.page.requestBusy,false); assert.equal(f.page.loading,false); assert.ok(f.page.errorMsg);
 const retry=f.page.loadSchedule(false); await until(()=>f.state.requests.length===2);
 f.state.requests[1].resolve({ok:false,error:'fixture error'}); await retry;
 assert.equal(f.page.errorMsg,'fixture error');
});
test('schedule tab preserves loaded courses when forced refresh throws',async()=>{
 const f=fixture('ScheduleTab'); f.page.alive=true; f.page.hasLoaded=true;
 f.page.allCourses=[{title:'fixture course'}];
 const task=f.page.loadSchedule(true); await until(()=>f.state.requests.length===1);
 f.state.requests[0].reject(Error('transport')); await task;
 assert.equal(f.page.allCourses[0].title,'fixture course'); assert.equal(f.page.hasLoaded,true);
 assert.equal(f.page.refreshing,false); assert.equal(f.state.toasts.length,1);
});
test('schedule tab ignores exceptions from a retired account',async()=>{
 const f=fixture('ScheduleTab'); f.page.alive=true; f.page.errorMsg='new account state';
 const task=f.page.loadSchedule(false); await until(()=>f.state.requests.length===1);
 f.state.epoch++; f.state.username='another-account';
 f.state.requests[0].reject(Error('transport')); await task;
 assert.equal(f.page.errorMsg,'new account state'); assert.equal(f.state.toasts.length,0); assert.equal(f.page.requestBusy,false);
});
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
test('profile request exception releases busy state and permits retry',async()=>{
 const {page,state}=fixture('ProfileTab'); page.alive=true;
 const first=page.loadProfile(); state.requests[0].reject(new Error('offline')); await first;
 assert.equal(page.requestBusy,false); assert.equal(page.loading,false); assert.ok(page.errorMsg.length>0);
 const second=page.loadProfile(); assert.equal(state.requests.length,2); state.requests[1].resolve({ok:true,data:{name:'fixture'}});await second; assert.equal(page.name,'fixture');
});
test('transaction labels describe the documented rolling 30-day range', () => {
  const source=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/TransactionsPage.ets'),'utf8');
  assert.ok(!source.includes('本月')); assert.ok(source.includes('最近30天'));
});
test('transactions without totalPages continue after full page and stop after short page', async () => {
  const {page,state}=fixture('TransactionsPage'); page.alive=true;
  const first=page.load(); state.requests[0].resolve({ok:true,data:{transactions:Array.from({length:20},(_,i)=>({journo:String(i)})),pageNo:1,pageSize:20}}); await first;
  assert.ok(page.nextPage<=page.totalPages); assert.equal(state.requests[0].params.pageSize,20);
  const second=page.load(false,true); assert.equal(state.requests[1].params.pageNo,2); state.requests[1].resolve({ok:true,data:{transactions:[{journo:'last'}],pageNo:2,pageSize:20}}); await second;
  assert.equal(page.items.length,21); assert.ok(page.nextPage>page.totalPages);
});
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
