'use strict';
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const zlib = require('node:zlib');
const {DatabaseSync} = require('node:sqlite');
assert.equal(crypto.createHash('sha256').update('abc').digest('hex'),
  'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
assert.equal(zlib.gunzipSync(zlib.gzipSync('preserved')).toString(), 'preserved');
assert.equal(Intl.DateTimeFormat.supportedLocalesOf(['bg-BG', 'ja-JP', 'ar-EG']).length, 3);
assert.equal(Temporal.PlainDate.from('2026-10-29').add({days: 1}).toString(), '2026-10-30');
const db = new DatabaseSync(':memory:');
assert.equal(db.prepare('select 6 * 7 as answer').get().answer, 42);
db.close();
console.log('runtime-ok');
