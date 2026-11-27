'use strict';
const {strict: assert} = require('assert');
const {execSync, spawnSync} = require('child_process');
const crypto = require('crypto');
const zlib = require('zlib');

const shell = process.argv[2];
assert.equal(execSync('printf %s "$BASH"', {encoding: 'utf8'}), shell);
const explicit = spawnSync('printf explicit', {shell, encoding: 'utf8'});
assert.equal(explicit.status, 0);
assert.equal(explicit.stdout, 'explicit');
assert.equal(crypto.createHash('sha256').update('abc').digest('hex'),
  'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
assert.equal(zlib.gunzipSync(zlib.gzipSync('preserved')).toString(), 'preserved');
assert.equal(Intl.DateTimeFormat.supportedLocalesOf(['bg-BG', 'ja-JP', 'ar-EG']).length, 3);
console.log('runtime-ok');
