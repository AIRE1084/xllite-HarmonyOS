'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const variants = [
  ['docs/brand/mountain-book-1024.png', 1024],
  ['docs/brand/mountain-book-216.png', 216],
  ['AppScope/resources/base/media/app_icon.png', 1024],
  ['entry/src/main/resources/base/media/icon.png', 1024],
];
let baseline = '';
for (const [relative, size] of variants) {
  const bytes = fs.readFileSync(path.join(root, relative));
  assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a', relative);
  assert.equal(bytes.toString('ascii', 12, 16), 'IHDR', relative);
  assert.equal(bytes.readUInt32BE(16), size, relative);
  assert.equal(bytes.readUInt32BE(20), size, relative);
  assert.ok(bytes.length < 3 * 1024 * 1024, relative);
  const hash = crypto.createHash('sha256').update(bytes).digest('hex');
  if (size === 1024) {
    if (!baseline) baseline = hash;
    assert.equal(hash, baseline, relative + ' diverges from store icon');
  }
  console.log('PASS ' + relative + ': ' + size + 'px, ' + bytes.length + ' bytes');
}
console.log('4 brand artifacts verified; pixel opacity and mask appearance require separate inspection');
