"use strict";
// Repeatable checks of actual ArkTS calendar/services with mocked system APIs.
// No account authentication, network, dependency downloads or device writes.
const fs = require('node:fs'), path = require('node:path'), vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const ts = require('D:/data/devecostudionext/DevEco Studio/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
const cases = [];
function test(name, run) { cases.push({name, run}); }
function deferred() { let resolve; const promise = new Promise(r => resolve = r); return {promise, resolve}; }
async function until(check) { for (let i=0; i<1000; i++) { if (check()) return; await Promise.resolve(); } throw new Error('Async checkpoint not reached'); }
function fixture() {
  const modules = new Map(), values = new Map(), disks = new Map(), stores = new Map(), openFiles = new Map();
  let nextFile = 1, nextReminder = 1, timer = 1;
  const state = { bundleName: 'com.xjit.app', now: new Date(2026, 9, 12, 7, 45).getTime(), reminders: new Map(), requests: [],
    cancelAll: 0, forms: [], widgetUpdates: [], liveStarts: [], liveUpdates: [], liveStops: [],
    notificationAllowed: true, liveAllowed: true, liveCode: 0, liveError: null, publishHook: null, stopFail: false };
  class Clock extends Date { constructor(...args) { if (!args.length) super(state.now); else super(...args); } static now() { return state.now; } }
  const preferences = { async getPreferences(_ctx, name) {
    if (!stores.has(name)) stores.set(name, new Map()); const store = stores.get(name);
    return { async get(k, fallback) { return store.has(k) ? store.get(k) : fallback; }, async put(k,v) {store.set(k,v);},
      async flush() {}, async delete(k) {store.delete(k);}, async clear() {store.clear();} };
  }};
  const nativeFs = { OpenMode: {CREATE:1, WRITE_ONLY:2, TRUNC:4},
    readTextSync(p) { if (!disks.has(p)) throw Error('not found'); return disks.get(p); },
    openSync(p) { const fd = nextFile++; openFiles.set(fd,p); return {fd}; },
    writeSync(fd,s) {if(state.writeFail)throw Error('write failed');disks.set(openFiles.get(fd),s);}, closeSync() {state.closedFiles=(state.closedFiles||0)+1;},
    renameSync(a,b) {if(state.renameFail)throw Error('rename failed');disks.set(b,disks.get(a)); disks.delete(a);} };
  const notification = {SlotType:{SERVICE_INFORMATION:2}, async requestEnableNotification(){}, async isNotificationEnabled(){return state.notificationAllowed;}};
  const reminder = {ReminderType:{REMINDER_TYPE_CALENDAR:1}, async cancelAllReminders(){state.cancelAll++; state.reminders.clear();},
    async getValidReminders(){if(state.validQueryFails)throw Error('query failed');return [...state.reminders.values()];},
     async cancelReminder(id){state.reminders.delete(id);}, async publishReminder(request){
      state.requests.push(request); if (state.publishHook) await state.publishHook(request);
      const id = nextReminder++; state.reminders.set(id,request); return id;
    }};
  const liveViewManager = {LifeCycleMode:{AUTO_STOP_WHEN_APP_TERMINATE:1}, CapsuleType:{CAPSULE_TYPE_TIMER:2},
    async isLiveViewEnabled(){return state.liveAllowed;}, async startLiveView(view){
      state.liveStarts.push(JSON.parse(JSON.stringify(view))); if(state.liveError) throw state.liveError;
      return {resultCode:state.liveCode,message:'mock'};
    }, async updateLiveView(view){state.liveUpdates.push(JSON.parse(JSON.stringify(view)));return {resultCode:0,message:'mock'};},
    async stopLiveView(view){state.liveStops.push(JSON.parse(JSON.stringify(view))); if(state.stopFail) throw {code:1003500003}; return {resultCode:0,message:'mock'};}};
  const formKit = {formBindingData:{createFormBindingData:data=>({data})}, formProvider:{async getPublishedRunningFormInfos(){return state.forms;},
    async updateForm(id,data){state.widgetUpdates.push({id,...data});}}};
  const wantAgent = {OperationType:{START_ABILITY:0}, WantAgentFlags:{UPDATE_PRESENT_FLAG:0}, async getWantAgent(options){return {options};}};
  function load(rel) {
    const full = path.resolve(root,rel); if(modules.has(full)) return modules.get(full).exports;
    const module={exports:{}}; modules.set(full,module);
    const js=ts.transpileModule(fs.readFileSync(full,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;
    const requireLocal = spec => {
      const native = {'@ohos.data.preferences':preferences,'@ohos.file.fs':nativeFs,'@ohos.notificationManager':notification,
        '@ohos.reminderAgentManager':reminder,'@ohos.app.ability.wantAgent':wantAgent};
      if(native[spec]) return {default:native[spec]};
      if(spec==='@kit.LiveViewKit') return {liveViewManager}; if(spec==='@kit.FormKit') return formKit;
      if(spec.startsWith('@ohos.')) return {default:{}};
      return load(path.relative(root,path.resolve(path.dirname(full),spec+'.ets')));
    };
    const context = vm.createContext({exports:module.exports,module,require:requireLocal,console,Date:Clock,Map,Set,Promise,
      AppStorage:{get:k=>values.get(k),set:(k,v)=>values.set(k,v),setOrCreate:(k,v)=>values.set(k,v)},
      setInterval:()=>timer++,clearInterval(){},setTimeout:()=>timer++,clearTimeout(){}});
    vm.runInContext(js,context,{filename:full}); return module.exports;
  }
  const get = file => load('entry/src/main/ets/'+file+'.ets');
  return {state,values,disks,stores,get,clock:Clock,calendar:get('utils/CourseCalendar'), layout:get('utils/ScheduleLayout'),time:get('utils/ClassTime'),weeks:get('utils/WeekParser'),
    async boot(){const core=get('services/CampusCompanionService');await core.initCampusCompanion({filesDir:'/data',abilityInfo:{bundleName:state.bundleName}});return core;}};
}
function course(extra={}) { return {day:'星期一',slot:'1-2节',title:'高等数学',teacher:'教师',weeks:'1-20周',sections:'1-2节',location:'教学楼A101',...extra}; }
function snapshot(extra={}) { return {account:'test-student',term:'2026-2027-1',courses:[course()],currentWeek:6,totalWeeks:20,weekKnown:true,
  anchorDate:'2026-10-12',updatedAt:new Date(2026,9,12).getTime(),widgetEnabled:true,...extra}; }
const plain=v=>JSON.parse(JSON.stringify(v));
async function readyCourse(f, courses=[course()], data={}) {
  const core=await f.boot(); await core.activateCampusCompanion('test-student');
  await core.acceptCampusSchedule('test-student',{term:'2026-2027-1',currentWeek:6,totalWeeks:20,courses,scheduleFetchedAt:f.state.now,...data},0); return core;
}

test('verified XJIT section clock matches confirmed 2026 autumn calendar',()=>{
 const f=fixture(); assert.deepEqual(plain(f.time.parseSections('1-2节')),[600,700]);
 assert.deepEqual(plain(f.time.parseSections('9-10节')),[1230,1330]);
 assert.equal(f.time.ALL_TIMES[4].label,'16:00 - 16:45');
});
test('invalid and out-of-range sections never crash or create false times',()=>{
 const f=fixture(); for(const text of ['12-13节','0-2节','1-a节','', '99999999-1']) assert.deepEqual(plain(f.time.parseSections(text)),[0,0]);
});
test('comma, bracket and reversed section lists normalize and retain gaps',()=>{
 const f=fixture(); assert.deepEqual(plain(f.time.sectionNumbers('[2,1,4]')),[1,2,4]);
 assert.deepEqual(plain(f.calendar.courseSectionGroups(course({sections:'1,2,4'}))),[[1,2],[4]]);
 assert.deepEqual(plain(f.time.sectionNumbers('第4–3节')),[3,4]);
});
test('course end boundary is exclusive',()=>{
 const f=fixture(), end=new Date(2026,9,12,9,40); assert.equal(f.time.classStatus(480,580,end),2); assert.equal(f.time.nextClassIndex([{startMinutes:480,endMinutes:580}],end),-1);
});
test('single/double weeks and Chinese separators match actual week',()=>{
 const f=fixture(); assert.equal(f.weeks.isCourseInWeek('1-16周（单）',5),true); assert.equal(f.weeks.isCourseInWeek('1-16周（单）',6),false);
 assert.equal(f.weeks.isCourseInWeek('[2，4，6]',6),true); assert.equal(f.weeks.isCourseInWeek('1-16周双',7),false);
});
test('invalid week labels are excluded and giant ranges are bounded',()=>{
 const f=fixture(); assert.equal(f.weeks.isCourseInWeek('invalid',3),false); assert.equal(f.weeks.isCourseInWeek('1-99999999周',20),true);
});
test('week rollover uses Monday and local calendar dates',()=>{
 const f=fixture(), s=snapshot(); assert.equal(f.calendar.weekOnDate(s,new Date(2026,9,18)),6); assert.equal(f.calendar.weekOnDate(s,new Date(2026,9,19)),7);
 assert.equal(f.calendar.weekOnDate(snapshot({weekKnown:false}),new Date(2026,9,12)),0);
});
test('next week reminders obey odd/even week rules',()=>{
 const f=fixture(), now=new Date(2026,9,18,7), s=snapshot({courses:[course({weeks:'1-20周单'})]});
 const items=f.calendar.buildOccurrences(s,now,7); assert.equal(items.length,1); assert.equal(items[0].week,7); assert.equal(new Date(items[0].startTime).getDate(),19);
});
test('missing week metadata, missing course weeks and unknown times do not schedule',()=>{
 const f=fixture(); assert.equal(f.calendar.buildOccurrences(snapshot({weekKnown:false}),new Date(2026,9,12)).length,0);
 assert.equal(f.calendar.buildOccurrences(snapshot({courses:[course({weeks:''}),course({sections:'12-13节'})]}),new Date(2026,9,12)).length,0);
});
test('duplicate API courses are deduplicated for reminders and rendering',()=>{
 const f=fixture(), courses=[course(),course()]; assert.equal(f.calendar.buildOccurrences(snapshot({courses}),new Date(2026,9,12),1).length,1);
 assert.equal(f.layout.scheduleBlocks(courses,6,20).length,1);
});
test('multi-section courses span rows and conflicting courses use separate lanes',()=>{
 const f=fixture(), blocks=f.layout.scheduleBlocks([course({sections:'1-4节'}),course({title:'物理',sections:'3-4节'})],6,20);
 assert.equal(blocks[0].first,1); assert.equal(blocks[0].last,4); assert.equal(blocks[0].lanes,2); assert.notEqual(blocks[0].lane,blocks[1].lane);
});
test('unrelated courses regain full width after overlapping cluster',()=>{
 const f=fixture(), blocks=f.layout.scheduleBlocks([course(),course({title:'物理'}),course({title:'英语',sections:'5-6节'})],6,20);
 assert.equal(blocks[2].lanes,1);
});
test('widget pause, logout and unknown weeks show no course information',()=>{
 const f=fixture(); assert.equal(f.calendar.widgetData(snapshot({widgetEnabled:false})).courseRoom,'');
 assert.equal(f.calendar.widgetData(null).courseTitle,'打开 APP 同步课表');
 assert.equal(f.calendar.widgetData(snapshot({weekKnown:false})).status,'待校准');
});
test('widget distinguishes no courses today from all courses ended',()=>{
 const f=fixture();
 assert.equal(f.calendar.widgetData(snapshot(),new Date(2026,9,17,12)).status,'今天没有课');
 assert.equal(f.calendar.widgetData(snapshot(),new Date(2026,9,12,23)).status,'今日课程已结束');
 assert.equal(f.calendar.widgetData(snapshot(),new Date(2026,9,12,9)).status,'下一节课');
});
test('widget lesson state observes inclusive start and exclusive end boundaries',()=>{
 const f=fixture(),data=snapshot();
 assert.equal(f.calendar.widgetData(data,new Date(2026,9,12,9,59,59)).status,'下一节课');
 assert.equal(f.calendar.widgetData(data,new Date(2026,9,12,10,0)).status,'上课中');
 assert.equal(f.calendar.widgetData(data,new Date(2026,9,12,11,39,59)).status,'上课中');
 const ended=f.calendar.widgetData(data,new Date(2026,9,12,11,40));
 assert.equal(ended.status,'今日课程已结束');assert.equal(ended.courseRoom,'');assert.equal(ended.courseTime,'');
});
test('notification denial leaves switch off with no published reminders',async()=>{
 const f=fixture(), core=await readyCourse(f); f.state.notificationAllowed=false;
 await assert.rejects(core.setCampusOption('reminders',true)); assert.equal(f.values.get('courseReminderEnabled'),false); assert.equal(f.state.reminders.size,0);
});
test('system calendar reminder is exactly ten minutes early and opens schedule',async()=>{
 const f=fixture(), core=await readyCourse(f); await core.setCampusOption('reminders',true);
 assert.equal(f.state.reminders.size,1); const request=f.state.requests[0]; assert.deepEqual(plain(request.dateTime),{year:2026,month:10,day:12,hour:9,minute:50});
 assert.equal(request.wantAgent.parameters.campusRoute,'schedule'); assert.equal(f.stores.get('xjit_campus_companion').get('reminders'),true);
});
test('turning reminders off cancels native reminders and persists switch',async()=>{
 const f=fixture(), core=await readyCourse(f);await core.setCampusOption('reminders',true);await core.setCampusOption('reminders',false);
 assert.equal(f.state.reminders.size,0);assert.equal(f.stores.get('xjit_campus_companion').get('reminders'),false);
});
test('switching off during native publication cancels the late reminder',async()=>{
 const f=fixture(), core=await readyCourse(f), gate=deferred();f.state.publishHook=()=>gate.promise;
 const enabled=core.setCampusOption('reminders',true);await until(()=>f.state.requests.length===1);
 const disabled=core.setCampusOption('reminders',false);await until(()=>f.values.get('courseReminderEnabled')===false);gate.resolve();await Promise.all([enabled,disabled]);
 assert.equal(f.state.reminders.size,0);
});
test('logout cancels reminders, clears widget snapshot and rejects stale schedule',async()=>{
 const f=fixture(), core=await readyCourse(f);await core.setCampusOption('widget',true);await core.setCampusOption('reminders',true);
 const cache=f.get('services/MemoryCache');await cache.clearAllCachedValues();await core.clearCampusCompanion();
 await core.acceptCampusSchedule('test-student',{term:'old',courses:[course()],currentWeek:6},0);
 assert.equal(f.state.reminders.size,0);assert.equal(f.disks.get('/data/campus_widget.json'),'null');assert.equal(core.getCampusWidgetData().courseRoom,'');
});
test('week calibration persists and the same cached response cannot reset it',async()=>{
 const f=fixture(), core=await readyCourse(f,[course()],{currentWeek:undefined});assert.equal(f.values.get('scheduleWeekKnown'),false);
 await core.calibrateCampusWeek(8);await core.acceptCampusSchedule('test-student',{term:'2026-2027-1',courses:[course()],scheduleFetchedAt:f.state.now},0);
 assert.equal(f.values.get('currentWeek'),8); assert.equal(JSON.parse(f.disks.get('/data/campus_widget.json')).weekKnown,true);
});
test('fresh calendar cannot overwrite manual calibration but new term resets it',async()=>{
 const f=fixture(),core=await readyCourse(f); await core.calibrateCampusWeek(8);
 await core.acceptCampusSchedule('test-student',{term:'2026-2027-1',courses:[course()],termStartDate:'2026-08-31',totalWeeks:19,scheduleFetchedAt:f.state.now+1},0);
 assert.equal(f.values.get('currentWeek'),8);
 await core.acceptCampusSchedule('test-student',{term:'2026-2027-2',courses:[course()],scheduleFetchedAt:f.state.now+2},0);
 assert.equal(f.values.get('scheduleWeekKnown'),false);
});
test('shortened semester invalidates out-of-range inherited calibration without corrupting snapshot',async()=>{
 const f=fixture(),core=await readyCourse(f);await core.calibrateCampusWeek(18);
 await core.acceptCampusSchedule('test-student',{term:'2026-2027-1',courses:[course()],totalWeeks:16,scheduleFetchedAt:f.state.now+1},0);
 const saved=f.get('services/WidgetService').readWidgetSnapshot({filesDir:'/data'});
 assert.ok(saved);assert.equal(saved.totalWeeks,16);assert.equal(saved.weekKnown,false);
 assert.equal(saved.manuallyCalibrated,false);assert.equal(saved.currentWeek,1);
});
test('shorter semester retains valid manual week and adopts source week after invalid calibration',async()=>{
 for(const [oldWeek,expected,manual] of [[8,8,true],[18,7,false]]){
  const f=fixture(),core=await readyCourse(f);await core.calibrateCampusWeek(oldWeek);
  await core.acceptCampusSchedule('test-student',{term:'2026-2027-1',courses:[course()],totalWeeks:16,currentWeek:7,scheduleFetchedAt:f.state.now+1},0);
  const saved=f.get('services/WidgetService').readWidgetSnapshot({filesDir:'/data'});
  assert.ok(saved);assert.equal(saved.currentWeek,expected);assert.equal(saved.weekKnown,true);assert.equal(saved.manuallyCalibrated,manual);
 }
});
test('companion ignores invalid semester totals consistently with schedule page',async()=>{
 for(const totalWeeks of [Infinity,NaN,0,-1,1.5,61,999]){
  const f=fixture();await readyCourse(f,[course()],{totalWeeks});
  assert.equal(f.get('services/WidgetService').readWidgetSnapshot({filesDir:'/data'}).totalWeeks,20);
 }
});
test('companion semester total accepts bounds alternate field and retains valid prior term total',async()=>{
 for(const [data,total] of [[{totalWeeks:1,currentWeek:1},1],[{totalWeeks:60},60],[{totalWeeks:Infinity,weeksTotal:19},19]]){
  const f=fixture();await readyCourse(f,[course()],data);
  assert.equal(f.get('services/WidgetService').readWidgetSnapshot({filesDir:'/data'}).totalWeeks,total);
 }
 const f=fixture(),core=await readyCourse(f,[course()],{totalWeeks:18});f.state.now+=1000;
 await core.acceptCampusSchedule('test-student',{term:'2026-2027-1',courses:[course()],totalWeeks:Infinity,scheduleFetchedAt:f.state.now},0);
 assert.equal(f.get('services/WidgetService').readWidgetSnapshot({filesDir:'/data'}).totalWeeks,18);
});
test('snapshot read boundary rejects invalid shape and week metadata',()=>{
 const f=fixture(),widgets=f.get('services/WidgetService'),ctx={filesDir:'/data'};
 for(const value of [{},snapshot({courses:[null]}),snapshot({courses:[course({weeks:12})]}),snapshot({totalWeeks:1.5}),snapshot({currentWeek:99}),snapshot({widgetEnabled:'yes'})]){
  f.disks.set('/data/campus_widget.json',JSON.stringify(value));assert.equal(widgets.readWidgetSnapshot(ctx),null);
 }
 f.disks.set('/data/campus_widget.json',JSON.stringify(snapshot()));assert.ok(widgets.readWidgetSnapshot(ctx));
});
test('malformed persisted snapshot renders pending widget instead of crashing',()=>{
 const f=fixture(),widgets=f.get('services/WidgetService'),ctx={filesDir:'/data'};
 for(const value of [{}, {account:null}, snapshot({courses:null}),snapshot({courses:[null]})]){
  f.disks.set('/data/campus_widget.json',JSON.stringify(value));
  assert.equal(widgets.buildWidgetBinding(ctx).data.status,'待同步');
 }
});
test('snapshot write and rename failures preserve last complete disk snapshot',async()=>{
 for(const failure of ['writeFail','renameFail']){
  const f=fixture();await readyCourse(f);const widgets=f.get('services/WidgetService'),ctx={filesDir:'/data'};
  const before=JSON.stringify(widgets.readWidgetSnapshot(ctx));const closed=f.state.closedFiles||0;
  f.state[failure]=true;assert.throws(()=>widgets.saveWidgetSnapshot(ctx,null));
  assert.equal(JSON.stringify(widgets.readWidgetSnapshot(ctx)),before);assert.equal(f.state.closedFiles,closed+1);
  f.state[failure]=false;widgets.saveWidgetSnapshot(ctx,null);assert.equal(widgets.readWidgetSnapshot(ctx),null);
 }
});
test('manual week marker and anchor survive snapshot disk roundtrip',async()=>{
 const f=fixture(),core=await readyCourse(f); await core.calibrateCampusWeek(8);
 const restored=f.get('services/WidgetService').readWidgetSnapshot({filesDir:'/data'});
 assert.equal(restored.manuallyCalibrated,true); assert.equal(restored.currentWeek,8); assert.equal(restored.anchorDate,'2026-10-12');
 await core.acceptCampusSchedule('test-student',{term:'2026-2027-1',courses:[course()],currentWeek:7,totalWeeks:19,scheduleFetchedAt:f.state.now+1},0);
 assert.equal(f.values.get('currentWeek'),8);
});
test('manual calibration rejects fractional and nonfinite weeks without mutation',async()=>{
 const f=fixture(),core=await readyCourse(f);
 for(const week of [NaN,Infinity,1.5]) await assert.rejects(core.calibrateCampusWeek(week));
 assert.equal(f.values.get('currentWeek'),6);
});
test('reminder registration is capped to leave system capacity',async()=>{
 const f=fixture(), courses=[];for(let day=1;day<=7;day++)for(let n=1;n<=10;n++)courses.push(course({day:String(day),sections:String(n),title:'课程'+day+'-'+n}));
 const core=await readyCourse(f,courses);await core.setCampusOption('reminders',true);assert.equal(f.state.reminders.size,24);
 assert.match(f.values.get('courseReminderStatus'),/已登记最近 24 条/);assert.match(f.values.get('courseReminderStatus'),/打开 APP 自动续订/);
});
test('system reminder quota preserves already registered courses',async()=>{
 const f=fixture();const core=await readyCourse(f,[course(),course({sections:'3-4节',title:'second'})]);
 let attempts=0;f.state.publishHook=async()=>{if(++attempts>1)throw {code:1700002};};
 await core.setCampusOption('reminders',true);
 assert.equal(f.state.reminders.size,1);assert.equal(f.values.get('courseReminderEnabled'),true);
 assert.match(f.values.get('courseReminderStatus'),/系统提醒受限（1700002）：容量或系统提醒控制限制/);
 assert.ok(!f.values.get('courseReminderStatus').includes('检查通知权限'));
});
test('quota status uses native reminder count without assuming zero on query failure',async()=>{
 for(const fails of [false,true]){
  const f=fixture(),core=await readyCourse(f);f.state.validQueryFails=fails;
  f.state.publishHook=async()=>{throw {code:1700002};};
  await core.setCampusOption('reminders',true);
  assert.ok(f.values.get('courseReminderStatus').includes(fails?'系统登记数量读取失败':'系统登记数量 0 条'));
 }
});
test('returning to app retries a quota-limited plan after capacity recovers',async()=>{
 const f=fixture(),core=await readyCourse(f,[course(),course({sections:'3-4节',title:'second'})]);
 f.state.publishHook=async()=>{throw {code:1700002};};
 await core.setCampusOption('reminders',true); assert.equal(f.state.reminders.size,0);
 f.state.publishHook=null; await core.activateCampusCompanion('test-student');
 assert.equal(f.state.reminders.size,2); assert.match(f.values.get('courseReminderStatus'),/已登记未来 7 天 2 条/);
 await core.setCampusOption('reminders',false); assert.equal(f.state.reminders.size,0);
});
test('invalid reminder parameters are not reported as notification permission failure',async()=>{
 const f=fixture(),core=await readyCourse(f); f.state.publishHook=async()=>{throw {code:401};};
 await assert.rejects(core.setCampusOption('reminders',true));
 assert.match(f.values.get('courseReminderStatus'),/提醒参数无效/);
 assert.equal(f.values.get('courseReminderEnabled'),false);
});
test('reminder failures distinguish permission notification and unknown errors and clean partial records',async()=>{
 for(const [code,text] of [[201,'提醒权限未授予（201）'],[1700001,'系统通知尚未开启（1700001）'],[999999,'提醒登记失败（999999），请稍后重试']]){
  const f=fixture(),core=await readyCourse(f,[course(),course({sections:'3-4节',title:'second'})]);
  let attempts=0;f.state.publishHook=async()=>{if(++attempts>1)throw {code};};
  await assert.rejects(core.setCampusOption('reminders',true));
  assert.equal(f.values.get('courseReminderStatus'),text);
  assert.equal(f.values.get('courseReminderEnabled'),false); assert.equal(f.state.reminders.size,0);
 }
});
test('real LiveView payload uses TIMER and millisecond duration',async()=>{
 const f=fixture();f.state.now=new Date(2026,9,12,9,51).getTime();const core=await readyCourse(f);await core.setCampusOption('live',true);
 assert.equal(f.state.liveStarts.length,1);const view=f.state.liveStarts[0];assert.equal(view.event,'TIMER');assert.equal(view.timer.time,9*60000);
 assert.equal(view.liveViewData.capsule.type,2);assert.equal(view.liveViewData.primary.clickAction.options.wants[0].parameters.campusRoute,'schedule');
});
test('enabled LiveView distinguishes waiting, empty day and active countdown from disabled state',async()=>{
 const f=fixture(),core=await readyCourse(f);await core.setCampusOption('live',true);
 assert.equal(f.state.liveStarts.length,0);assert.equal(f.values.get('liveViewStatus'),'已开启，等待进入课前 10 分钟');
 f.state.now=new Date(2026,9,12,9,51).getTime();await core.activateCampusCompanion('test-student');
 assert.equal(f.state.liveStarts.length,1);assert.equal(f.values.get('liveViewStatus'),'实况窗已显示');
 f.state.now=new Date(2026,9,12,12,0).getTime();await core.activateCampusCompanion('test-student');
 assert.equal(f.state.liveStops.length,1);assert.equal(f.values.get('liveViewStatus'),'已开启，今天暂无后续课程');
 await core.setCampusOption('live',false);assert.equal(f.values.get('liveViewStatus'),'已关闭课程实况窗');
 const g=fixture(),pending=await g.boot();await pending.setCampusOption('live',true);
 assert.equal(g.values.get('liveViewStatus'),'已开启，等待课表同步和当前周次校准');assert.equal(g.state.liveStarts.length,0);
});
test('missing abilityInfo at emulator startup still resolves the launched bundle safely',async()=>{
 const f=fixture(),core=f.get('services/CampusCompanionService');await core.initCampusCompanion({filesDir:'/data'},'com.xjit.app.designreview');assert.equal(core.getCampusBundleName(),'com.xjit.app.designreview');
 const g=fixture(),fallback=g.get('services/CampusCompanionService');await fallback.initCampusCompanion({filesDir:'/data',applicationInfo:{name:'com.xjit.app.acceptance'}});assert.equal(fallback.getCampusBundleName(),'com.xjit.app.acceptance');
 const h=fixture(),formal=h.get('services/CampusCompanionService');await formal.initCampusCompanion({filesDir:'/data'});assert.equal(formal.getCampusBundleName(),'com.xjit.app');
});
test('reminder taps return to the running app bundle and course schedule',async()=>{
 const f=fixture();f.state.bundleName='com.xjit.app.designreview';const core=await readyCourse(f);await core.setCampusOption('reminders',true);
 assert.ok(f.state.requests.length>0);for(const request of f.state.requests){assert.equal(request.wantAgent.pkgName,f.state.bundleName);assert.equal(request.wantAgent.abilityName,'EntryAbility');assert.equal(request.wantAgent.parameters.campusRoute,'schedule');}
});
test('LiveView taps return to the running app bundle and course schedule',async()=>{
 const f=fixture();f.state.bundleName='com.xjit.app.acceptance';f.state.now=new Date(2026,9,12,9,51).getTime();const core=await readyCourse(f);await core.setCampusOption('live',true);
 assert.equal(f.state.liveStarts.length,1);const action=f.state.liveStarts[0].liveViewData.primary.clickAction.options.wants[0];assert.equal(action.bundleName,f.state.bundleName);assert.equal(action.abilityName,'EntryAbility');assert.equal(action.parameters.campusRoute,'schedule');
});
test('LiveView permission denial is reported and never presented as success',async()=>{
 const f=fixture();f.values.set('liveViewEnabled',true);f.state.liveError={code:1003500005};const live=f.get('services/LiveViewService');
 const result=await live.startCourseLiveView(course(),f.state.now+60000,f.state.now+3600000);
 assert.equal(result.ok,false);assert.match(result.reason,/尚未获批/);assert.equal(live.getCurrentHandle(),null);
});
test('partial LiveView result is cleaned up and is not success',async()=>{
 const f=fixture();f.values.set('liveViewEnabled',true);f.state.liveCode=4;const live=f.get('services/LiveViewService');
 const result=await live.startCourseLiveView(course(),f.state.now+60000,f.state.now+3600000);assert.equal(result.ok,false);assert.equal(f.state.liveStops.length,1);
});
test('minute-of-day values are rejected by real LiveView adapter',async()=>{
 const f=fixture();f.values.set('liveViewEnabled',true);const result=await f.get('services/LiveViewService').startCourseLiveView(course(),480,580);
 assert.equal(result.ok,false);assert.equal(f.state.liveStarts.length,0);
});
test('course LiveView changes timer at class start and stops on switch off',async()=>{
 const f=fixture();f.state.now=new Date(2026,9,12,9,51).getTime();const core=await readyCourse(f);await core.setCampusOption('live',true);
 f.state.now=new Date(2026,9,12,10,1).getTime();await core.activateCampusCompanion('test-student');assert.equal(f.state.liveUpdates.length,1);
 assert.equal(f.state.liveUpdates[0].liveViewData.capsule.content,'上课中');assert.equal(f.values.get('liveViewStatus'),'实况窗已显示');
 await core.activateCampusCompanion('test-student');assert.equal(f.values.get('liveViewStatus'),'实况窗已显示');
 await core.setCampusOption('live',false);assert.equal(f.state.liveStops.length,1);
});
test('failed LiveView stop cannot prevent logout privacy and reminder cleanup',async()=>{
 const f=fixture();f.state.now=new Date(2026,9,12,7,49).getTime();const core=await readyCourse(f);await core.setCampusOption('reminders',true);await core.setCampusOption('live',true);
 f.state.stopFail=true;await core.clearCampusCompanion();assert.equal(f.state.reminders.size,0);assert.equal(f.disks.get('/data/campus_widget.json'),'null');
});
(async()=>{
 const results=[];for(const {name,run} of cases){try{await run();results.push({name,ok:true});console.log('PASS '+name);}catch(error){results.push({name,ok:false,error:error.message});console.error('FAIL '+name+'\n'+error.stack);}}
 const failed=results.filter(r=>!r.ok);const report={checkedAt:new Date().toISOString(),networkUsed:false,nativeApisMocked:true,checks:results.length,failed:failed.length,results};
 fs.writeFileSync(path.join(root,'.wolf/campus-companion-checks.json'),JSON.stringify(report,null,2)+'\n');console.log(`${results.length} checks, ${failed.length} failed`);if(failed.length)process.exitCode=1;
})();
