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
const installer = fs.readFileSync(path.join(root, 'install-dvs-mode-switcher.sh'), 'utf8');

assert.strictEqual(packageJson.version, '1.1.1');
assert.strictEqual(packageLock.version, '1.1.1');
assert.strictEqual(packageLock.packages[''].version, '1.1.1');
assert.match(readme, /version-1\.1\.1-2563eb/);
assert.doesNotMatch(readme.split('## 1.1.1')[0], /1\.1\.1-rc/i);
assert.match(server, /this\.app\.locals\.productName = 'DVS Mode Switcher'/);
assert.match(server, /this\.app\.locals\.appVersion = packageInfo\.version/);
assert.match(indexView, /<title><%= productName %> v<%= appVersion %><\/title>/);
const renderedIndex = ejs.render(indexView, { productName: 'DVS Mode Switcher', appVersion: '1.1.1', modes: [], usrpEnabled: false }, { filename: path.join(root, 'views/index.ejs') });
assert.match(renderedIndex, /<title>DVS Mode Switcher v1\.1\.1<\/title>/);
assert.doesNotMatch(renderedIndex, /-rc[0-9]+/i);

for (const serviceFile of ['installer/dvswitch_mode_switcher.service']) {
  const service = fs.readFileSync(path.join(root, serviceFile), 'utf8');
  assert.match(service, /^Description=DVS Mode Switcher web interface$/m);
  assert.match(service, /^User=asl$/m);
  assert.doesNotMatch(service, /^User=root$/m);
}

assert.doesNotMatch(readme, /port 3001|TEST VERSION|node68425|testnode/i);
assert.match(readme, /\| ♻️ Restore \| Explicit `--restore` option \| Lists the available restore points/);
assert.match(readme, /Running `--restore` lists the available permanent installation backups/);
assert.match(readme, /Restore creates a separate permanent safety snapshot/);

const brandingFiles = [
  'index.js',
  'models/Mode.js',
  'models/Talkgroup.js',
  'public/js/edit.js',
  'public/js/index.js',
  'configs/config.example.yml',
  'installer/dvswitch_mode_switcher.service',
  'install-dvs-mode-switcher.sh',
  'views/index.ejs'
];

for (const filename of brandingFiles) {
  const contents = fs.readFileSync(path.join(root, filename), 'utf8');
  assert.doesNotMatch(contents, /DVSwitch Mode Switcher/);
}

assert.ok(fs.existsSync(path.join(root, 'install-dvs-mode-switcher.sh')));
assert.ok(!fs.existsSync(path.join(root, 'install-dvswitch-mode-switcher.sh')));
assert.match(installer, /Removing installation-only files from the production application/);
assert.match(installer, /rm -rf -- "\$APP_DIR\/\.git" "\$APP_DIR\/tests" "\$APP_DIR\/installer" "\$APP_DIR\/presets"/);
assert.match(installer, /rm -f --[^\n]*"\$APP_DIR\/install-dvs-mode-switcher\.sh"/);
assert.match(installer, /"\$OLD_APP" == \/opt\/dvswitch_mode_switcher\.before-\*/);
assert.doesNotMatch(installer, /\.failed-\$STAMP/);

process.stdout.write('Stable-release housekeeping regression test passed.\n');
