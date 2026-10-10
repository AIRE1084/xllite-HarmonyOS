"use strict";
// Offline UI preview injection, ONLY in the owned simulator staging directory.
// Does not create an HTTP service, change HDC mappings, contact APIs or enable payments.
const fs = require('node:fs');
const path = require('node:path');
const sourceRoot = path.resolve(__dirname, '..');
const stage = path.resolve(process.argv[2] || '');
if (stage === sourceRoot || stage.startsWith(sourceRoot + path.sep)) throw new Error('Cannot patch production source.');
if (fs.readFileSync(path.join(stage, '.codex-xjit-simulator'), 'utf8').replace(/^\uFEFF/, '').trim() !== sourceRoot) throw new Error('Stage ownership mismatch.');
const app = JSON.parse(fs.readFileSync(path.join(stage, 'AppScope/app.json5'), 'utf8').replace(/^\uFEFF/, ''));
if (app.app.bundleName !== 'com.xjit.app.designreview') throw new Error('Only com.xjit.app.designreview may contain offline data.');
function edit(relative, transform) {
  const file = path.join(stage, relative);
  const before = fs.readFileSync(file, 'utf8');
  const after = transform(before);
  if (after === before) throw new Error('Patch anchor missing: ' + relative);
  fs.writeFileSync(file, after, 'utf8');
}
function course(day, sections, title, location, weeks = '1-20周') {
  return { day, slot: sections, sections, title, location, teacher: '示例教师', weeks };
}
const courses = [
  course('星期一','1-2节','高等数学','A201'), course('星期一','5-6节','大学英语','A305'),
  course('星期二','3-4节','数据结构','B302'), course('星期二','7-8节','体育','体育馆'),
  course('星期三','1-2节','大学英语','A305'), course('星期三','5-6节','软件工程','B301'),
  course('星期四','3-4节','计算机网络','B208'), course('星期四','7-8节','高等数学','A201'),
  course('星期五','1-2节','软件工程','B301'), course('星期五','5-6节','校园实践与软件设计','实训楼 C302'),
  course('星期五','9-10节','算法设计与分析','B306','2-20周(双)'),
  course('星期六','3-4节','创新实践','创客中心','1-9周'),
];
const summary = {courseCount:2,totalCredits:6,gpaCredits:6,weightedGradePoint:3.8,failedCourseCount:0,failedCredits:0};
const data = {
 'jw.schedule': {term:'2026-2027-1',currentWeek:6,totalWeeks:20,courses},
 'jw.profile': {studentId:'2026000001',name:'示例同学',college:'信息工程学院',major:'软件工程',className:'软件工程一班',grade:'2026',gender:'男'},
 'newcard.balance': {accounts:[{typeCode:'1',typeName:'校园卡账户',balance:'128.50',unit:'元'}]},
 'jw.exams': {exams:[{courseName:'软件工程',teacher:'示例教师',examTime:'2026-12-18 09:00-11:00',examPlace:'教学楼 A201',seatNo:'12',courseCode:'PREVIEW001',examSession:'期末',campus:'主校区'}]},
 'jw.grades': {mode:'all',summary,rawSummary:summary,terms:[{term:'2026-2027-1',...summary}],normalGrades:[
  {term:'2026-2027-1',courseCode:'PREVIEW001',courseName:'软件工程',score:'92',credit:'3',gradePoint:'4.0',examNature:'正常',scoreFlag:'',makeupTerm:''},
  {term:'2026-2027-1',courseCode:'PREVIEW002',courseName:'数据结构',score:'88',credit:'3',gradePoint:'3.6',examNature:'正常',scoreFlag:'',makeupTerm:''}],makeupGrades:[],failedCourses:[]},
 'jw.training': {training:[{graduationYear:'2030',graduationType:'本科',graduationConclusion:'示例培养信息',graduationTime:'2030-06',certificateNo:'PREVIEW-ONLY'}]},
 'newcard.transactions': {fromDate:'2026-10-01',toDate:'2026-10-09',pageNo:1,pageSize:20,transactions:[
  {date:'2026-10-09 12:00:00',summary:'食堂消费（示例）',merchantName:'校园食堂',amount:'-12.00',isRefund:false,operation:false,journo:'PREVIEW001'},
  {date:'2026-10-08 10:00:00',summary:'校园卡充值（示例）',merchantName:'校园卡账户',amount:'50.00',isRefund:false,operation:false,journo:'PREVIEW002'}]},
 'newcard.recharge.config': {balance:'128.50',idSerial:'PREVIEW',username:'示例同学',amountOptions:[],payMethods:[],canPayOther:false,hostApp:false,daLianPayEnable:false,wapPayEnable:false},
 'newcard.electricity.account': {remainingElectricity:{value:'68.5',unit:'kWh'},room:{query:'1-101',buildingName:'示例一号楼',levelName:'一层',roomName:'101'}},
};
// JSON.parse provides the same typed payload shape that production normalization consumes.
const payload = JSON.stringify(data).replace(/'/g, "\\'");
fs.writeFileSync(path.join(stage, 'entry/src/main/ets/services/OfflineDesignData.ets'),
  `export function offlineDesignData(feature: string): Record<string, Object> | null {\n` +
  `  const all = JSON.parse('${payload}') as Record<string, Object>\n` +
  `  const value = all[feature]\n` +
  `  return value === undefined ? null : value as Record<string, Object>\n}\n`, 'utf8');
edit('entry/src/main/ets/services/ApiService.ets', source => {
  source = "import { offlineDesignData } from './OfflineDesignData'\n" + source;
  const tokenStart = source.indexOf('async function loginForToken(');
  const tokenEnd = source.indexOf('async function requestWithToken(', tokenStart);
  if (tokenStart < 0 || tokenEnd < 0) throw new Error('Token patch anchor missing');
  source = source.slice(0, tokenStart) + `async function loginForToken(username: string, password: string): Promise<TokenResult> {
  const result = new TokenResult()
  result.ok = username === '2026000001' && password === 'offline-preview'
  result.token = result.ok ? 'offline-design-only' : ''
  result.error = result.ok ? '' : '离线设计预览只使用内置示例账号'
  if (result.ok) await saveAccessToken(result.token, 86400)
  return result
}

` + source.slice(tokenEnd);
  const requestStart = source.indexOf('async function requestWithToken(');
  const requestEnd = source.indexOf('export async function login(', requestStart);
  source = source.slice(0, requestStart) + `async function requestWithToken(path: string, method: http.RequestMethod, token: string): Promise<CallResult> {
  const result = new CallResult()
  result.ok = path === '/api/v1/auth/logout'
  result.error = result.ok ? '' : '离线预览不连接网络'
  return result
}

` + source.slice(requestEnd);
  const runStart = source.indexOf('async function runFeatureOnce(');
  const runEnd = source.indexOf('function expiredSessionResult(', runStart);
  if (runStart < 0 || runEnd < 0) throw new Error('Run patch anchor missing');
  return source.slice(0, runStart) + `async function runFeatureOnce(feature: string, params: Record<string, Object>, token: string): Promise<CallResult> {
  await new Promise<void>((resolve) => { setTimeout(() => { resolve() }, 180) })
  const result = new CallResult()
  const data = offlineDesignData(feature)
  if (data !== null) { result.ok = true; result.data = normalizeFeatureData(feature, data) }
  else result.error = '离线设计预览不提供付款码、支付或此项服务'
  return result
}

` + source.slice(runEnd);
});
edit('entry/src/main/ets/services/AuthManager.ets', source => source.replace(/await initPublicKey\(\)/g, 'await Promise.resolve()'));
edit('entry/src/main/ets/pages/LoginPage.ets', source => source.replace('const hasSession = await loadSession()', "await saveSession('2026000001', 'offline-preview')\n    const hasSession = await loadSession()"));
edit('entry/src/main/ets/components/common/CampusHeader.ets', source => source.replace('Text(this.subtitle)', "Text('离线示例 · ' + this.subtitle)"));
edit('entry/src/main/ets/components/common/DetailHeader.ets', source => source.replace('Text(this.subtitle)', "Text('离线示例 · ' + this.subtitle)"));
edit('entry/src/main/ets/utils/Constants.ets', source => source.replace(/export const API_BASE: string = '[^']+'/, "export const API_BASE: string = 'https://offline-preview.invalid'"));
// Network permission is removed from the preview manifest as an additional compile-time boundary.
const moduleFile = path.join(stage, 'entry/src/main/module.json5');
const moduleConfig = JSON.parse(fs.readFileSync(moduleFile, 'utf8').replace(/^\uFEFF/, ''));
moduleConfig.module.requestPermissions = (moduleConfig.module.requestPermissions || []).filter(item => item.name !== 'ohos.permission.INTERNET');
fs.writeFileSync(moduleFile, JSON.stringify(moduleConfig, null, 2), 'utf8');
console.log('Isolated offline design preview: synthetic data; network permission removed; no HTTP, port mapping or payment code.');
