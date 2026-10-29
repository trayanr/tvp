'use strict';
const assert = require('node:assert/strict');
const {execSync, spawnSync} = require('node:child_process');
const shell = process.argv[2];
assert.equal(execSync('printf %s "$BASH"', {encoding: 'utf8'}), shell);
assert.equal(spawnSync('printf explicit', {shell, encoding: 'utf8'}).stdout, 'explicit');
console.log('shell-ok');
