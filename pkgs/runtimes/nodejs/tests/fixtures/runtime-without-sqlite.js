'use strict';
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const zlib = require('node:zlib');
assert.equal(crypto.createHash('sha256').update('abc').digest('hex'),
  'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
assert.equal(zlib.gunzipSync(zlib.gzipSync('preserved')).toString(), 'preserved');
assert.equal(Intl.DateTimeFormat.supportedLocalesOf(['bg-BG', 'ja-JP', 'ar-EG']).length, 3);
assert.equal(typeof globalThis.Temporal, 'undefined');
assert.throws(() => require('node:sqlite'), {code: 'ERR_UNKNOWN_BUILTIN_MODULE'});
console.log('runtime-ok');
