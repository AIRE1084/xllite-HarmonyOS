'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const pages = path.join(root, 'entry/src/main/ets/pages');
let checks = 0;
let failed = 0;
function check(name, run) {
  checks++;
  try { run(); console.log('PASS ' + name); }
  catch (error) { failed++; console.error('FAIL ' + name + ': ' + error.message); }
}
for (const file of fs.readdirSync(pages).filter(name => name.endsWith('.ets'))) {
  const source = fs.readFileSync(path.join(pages, file), 'utf8');
  const transition = source.match(/pageTransition\(\):\s*void\s*\{([\s\S]*?)\n  \}/);
  if (!transition) continue;
  check(file + ' transition contains no local declarations', () => {
    assert.doesNotMatch(transition[1], /\b(?:const|let|var)\s/,
      'ArkUI transition builders require component syntax; inline the duration expression');
    assert.match(transition[1], /duration:\s*motionDuration\(Motion\.duration\.base\)/);
  });
}
check('LoginPage theme overlay remains inside the root Stack', () => {
  const source = fs.readFileSync(path.join(pages, 'LoginPage.ets'), 'utf8');
  assert.match(source, /\n      ThemeWash\(\)\n    \}\.width\('100%'\)\.height\('100%'\)\.backgroundColor\(this\.palette\.background\)\n  \}/);
});
console.log(`${checks} UI structure checks, ${failed} failed`);
process.exitCode = failed ? 1 : 0;
