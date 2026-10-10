// Local-only fixtures for the isolated com.xjit.app.acceptance emulator build.
// No dependencies, upstream requests, real credentials or payment operations.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const port = Number(process.env.XJIT_FIXTURE_PORT || 18765);
const records = path.resolve(__dirname, '../.wolf/emulator');
fs.mkdirSync(records, { recursive: true });
const logFile = path.join(records, 'requests.jsonl');
const token = 'emulator-fixture-token';
const methods = [{ code: 'fixture', tradeType: 'SIMULATOR', name: '模拟支付（不可付款）', h5: false, successToHome: false, signBind: '' }];
const amounts = ['20', '50', '100'].map(amount => ({ id: amount, amount, name: amount + '元' }));
const room = { query: '1-101', buildingName: '模拟一号楼', levelName: '一层', roomName: '101' };
const profile = { studentId: '2026000001', name: '模拟同学', college: '信息工程学院', major: '软件工程', className: '模拟班', grade: '2026', gender: '男' };
const courses = ['星期一', '星期二', '星期三', '星期四', '星期五'].flatMap((day, i) => [
  { day, slot: '1-2节', sections: '1-2节', title: ['高等数学', '数据结构', '大学英语', '计算机网络', '软件工程'][i], teacher: '模拟教师', weeks: '1-20周', location: '教学楼 A' + (201 + i) },
  { day, slot: '5-6节', sections: '5-6节', title: '校园实践与软件设计', teacher: '模拟教师', weeks: '1-20周', location: '实训楼 B301' }
]);
const summary = { courseCount: 2, totalCredits: 6, gpaCredits: 6, weightedGradePoint: 3.8, failedCourseCount: 0, failedCredits: 0 };
const featureData = {
  'jw.schedule': { term: '2026-2027-1', currentWeek: 6, totalWeeks: 20, courses },
  'newcard.balance': { accounts: [{ typeCode: '1', typeName: '校园卡账户', balance: '128.50', unit: '元' }] },
  'jw.profile': profile,
  'jw.exams': { exams: [{ courseName: '软件工程（模拟）', teacher: '模拟教师', examTime: '2026-12-18 09:00-11:00', examPlace: '教学楼 A201', seatNo: '12', courseCode: 'SIM001', examSession: '期末', campus: '主校区' }] },
  'jw.grades': { mode: 'all', summary, rawSummary: summary, terms: [{ term: '2026-2027-1', ...summary }], normalGrades: [
    { term: '2026-2027-1', courseCode: 'SIM001', courseName: '软件工程', score: '92', credit: '3', gradePoint: '4.0', examNature: '正常', scoreFlag: '', makeupTerm: '' },
    { term: '2026-2027-1', courseCode: 'SIM002', courseName: '数据结构', score: '88', credit: '3', gradePoint: '3.6', examNature: '正常', scoreFlag: '', makeupTerm: '' }
  ], makeupGrades: [], failedCourses: [] },
  'jw.training': { training: [{ graduationYear: '2030', graduationType: '本科', graduationConclusion: '模拟培养信息', graduationTime: '2030-06', certificateNo: 'SIMULATOR-ONLY' }] },
  'newcard.transactions': { fromDate: '2026-10-01', toDate: '2026-10-09', pageNo: 1, pageSize: 20, transactions: [
    { date: '2026-10-09 12:00:00', summary: '食堂消费（模拟）', merchantName: '校园食堂', amount: '-12.00', isRefund: false, operation: false, journo: 'SIM001' },
    { date: '2026-10-08 10:00:00', summary: '模拟充值', merchantName: '模拟账户', amount: '50.00', isRefund: false, operation: false, journo: 'SIM002' }
  ] },
  'newcard.recharge.config': { balance: '128.50', idSerial: 'SIMULATOR', username: '模拟同学', amountOptions: amounts, payMethods: methods, canPayOther: false, hostApp: false, daLianPayEnable: false, wapPayEnable: false },
  'newcard.electricity.account': { remainingElectricity: { value: '68.5', unit: 'kWh' }, room },
  'newcard.electricity.recharge.config': { room, account: { utilityAccount: 'SIMULATOR', utilityUsername: '模拟宿舍', utilityStatusName: '正常', accStatusName: '正常' }, remainingElectricity: { value: '68.5', unit: 'kWh' }, cardBalance: { value: '128.50', unit: '元' }, price: { value: '0.5', unit: '元/kWh' }, amountOptions: amounts, payMethods: methods, needPaymentPassword: false, canPayOther: false, confirm: true, hostApp: false, amtInputDisabled: false, tip: '本地模拟数据，不能执行真实支付' }
};
let sequence = 0;
const server = http.createServer(async (req, res) => {
  const start = Date.now();
  let raw = '';
  for await (const chunk of req) { raw += chunk; if (raw.length > 16384) { res.writeHead(413); res.end(); return; } }
  let body;
  try { body = raw ? JSON.parse(raw) : {}; } catch { res.writeHead(400); res.end(); return; }
  const id = ++sequence;
  const entry = { id, at: new Date().toISOString(), path: req.url, feature: typeof body.feature === 'string' ? body.feature : '' };
  fs.appendFileSync(logFile, JSON.stringify({ ...entry, event: 'start' }) + '\n');
  let status = 200;
  let result;
  if (req.url === '/api/v1/auth/login') {
    if (body.username === '2026000001' && body.password === 'fixture-only') result = { ok: true, data: { accessToken: token, expiresInSeconds: 3600 } };
    else { status = 401; result = { ok: false, error: '验收包仅接受本地模拟账号' }; }
  } else if (req.headers.authorization !== 'Bearer ' + token) {
    status = 401; result = { ok: false, error: '模拟会话无效' };
  } else if (req.url === '/api/v1/auth/logout') {
    result = { ok: true };
  } else if (req.url === '/api/v1/run' && body.feature === 'newcard.campus_code.qrcode') {
    result = { ok: true, data: { mode: 'simulator', qrcode: 'SIMULATOR-NOT-FOR-PAYMENT-' + id, qrcodeType: 'SIMULATOR', expiresInSeconds: 12, balance: '128.50', idSerial: 'SIMULATOR', userName: '模拟同学', displayInfo: true, displayBalance: true } };
  } else if (req.url === '/api/v1/run' && featureData[body.feature]) {
    result = { ok: true, data: featureData[body.feature] };
  } else result = { ok: false, error: '本地验收不执行支付或未知接口' };
  // A small deterministic delay makes loading and request coalescing observable.
  await new Promise(resolve => setTimeout(resolve, body.feature === 'jw.schedule' ? 300 : 120));
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(result));
  fs.appendFileSync(logFile, JSON.stringify({ ...entry, event: 'end', status, elapsedMs: Date.now() - start }) + '\n');
});
server.listen(port, '127.0.0.1', () => console.log('Local emulator fixtures ready at 127.0.0.1:' + port));
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => server.close(() => process.exit(0)));
