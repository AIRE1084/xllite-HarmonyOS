'use strict';
// Public and unauthenticated checks only. Never accepts or logs user credentials.
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const base = 'https://xllite.sayqz.com';
(async () => {
  const results = [];
  async function check(name, endpoint, options, verify) {
    try {
      const response = await fetch(base + endpoint, { ...options, signal: AbortSignal.timeout(15000) });
      const body = await response.json(); verify(response.status, body);
      results.push({ name, pass: true, status: response.status }); console.log('PASS ' + name + ' HTTP ' + response.status);
      return body;
    } catch (e) { results.push({ name, pass: false, error: e.message }); console.error('FAIL ' + name + ': ' + e.message); }
  }
  await check('health', '/health', {}, (s,b) => { assert.equal(s,200); assert.equal(b.ok,true); });
  await check('public OpenAPI', '/api/v1/openapi.json', {}, (s,b) => { assert.equal(s,200); assert.ok(b.paths['/api/v1/auth/login']); assert.ok(b.paths['/api/v1/run']); });
  await check('public feature details', '/api/v1/features/detail', {}, (s,b) => { assert.equal(s,200); assert.ok(Array.isArray(b.features)); assert.ok(b.features.some(f => f.name === 'jw.profile')); });
  await check('public academic calendar', '/api/v1/academic-calendar', {}, (s,b) => { assert.equal(s,200); assert.equal(b.ok,true); });
  await check('session rejects absent bearer', '/api/v1/auth/session', {}, (s,b) => { assert.equal(s,401); assert.equal(b.ok,false); });
  await check('business rejects absent bearer', '/api/v1/run', {method:'POST', headers:{'Content-Type':'application/json'},body:JSON.stringify({feature:'jw.profile',params:{}})}, (s,b) => { assert.ok(s >= 400 && s < 500); assert.equal(b.ok,false); });
  const report={checkedAt:new Date().toISOString(),base,credentialsUsed:false,paymentsExecuted:false,results};
  const dest=path.resolve(__dirname,'../.wolf/api23-native-login'); fs.mkdirSync(dest,{recursive:true}); fs.writeFileSync(path.join(dest,'live-public-checks.json'),JSON.stringify(report,null,2));
  console.log(`${results.length} live public checks, ${results.filter(r=>!r.pass).length} failed`);process.exitCode=results.some(r=>!r.pass)?1:0;
})();
