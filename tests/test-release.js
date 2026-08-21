'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const ejs = require('ejs');

const root = path.resolve(__dirname, '..');
const packageJson = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
const packageLock = JSON.parse(fs.readFileSync(path.join(root, 'package-lock.json'), 'utf8'));
const readme = fs.readFileSync(path.join(root, 'README.md'), 'utf8');
const server = fs.readFileSync(path.join(root, 'modules/Server.js'), 'utf8');
const indexView = fs.readFileSync(path.join(root, 'views/index.ejs'), 'utf8');

assert.strictEqual(packageJson.version, '1.1.0');
assert.strictEqual(packageLock.version, '1.1.0');
assert.strictEqual(packageLock.packages[''].version, '1.1.0');
assert.match(readme, /version-1\.1\.0-2563eb/);
assert.doesNotMatch(readme.split('## 1.1.0')[0], /1\.1\.0-rc/i);
assert.match(server, /this\.app\.locals\.productName = 'DVS Mode Switcher'/);
assert.match(server, /this\.app\.locals\.appVersion = packageInfo\.version/);
assert.match(indexView, /<title><%= productName %> v<%= appVersion %><\/title>/);
const renderedIndex = ejs.render(indexView, { productName: 'DVS Mode Switcher', appVersion: '1.1.0', modes: [], usrpEnabled: false }, { filename: path.join(root, 'views/index.ejs') });
assert.match(renderedIndex, /<title>DVS Mode Switcher v1\.1\.0<\/title>/);
assert.doesNotMatch(renderedIndex, /-rc[0-9]+/i);

for (const serviceFile of ['installer/dvswitch_mode_switcher.service', 'debian/dvswitch_mode_switcher.service']) {
  const service = fs.readFileSync(path.join(root, serviceFile), 'utf8');
  assert.match(service, /^Description=DVS Mode Switcher web interface$/m);
  assert.match(service, /^User=asl$/m);
  assert.doesNotMatch(service, /^User=root$/m);
}

assert.doesNotMatch(readme, /port 3001|TEST VERSION|node68425|testnode/i);

const brandingFiles = [
  'index.js',
  'models/Mode.js',
  'models/Talkgroup.js',
  'public/js/edit.js',
  'public/js/index.js',
  'configs/config.example.yml',
  'configs/tg_alias.example.yml',
  'installer/dvswitch_mode_switcher.service',
  'install-dvswitch-mode-switcher.sh',
  'views/index.ejs'
];

for (const filename of brandingFiles) {
  const contents = fs.readFileSync(path.join(root, filename), 'utf8');
  assert.doesNotMatch(contents, /DVSwitch Mode Switcher/);
}

process.stdout.write('Stable-release housekeeping regression test passed.\n');
