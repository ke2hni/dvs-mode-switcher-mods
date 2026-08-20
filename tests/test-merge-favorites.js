'use strict';

const assert = require('assert');
const childProcess = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const YAML = require('yaml');

const root = path.resolve(__dirname, '..');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'dvs-favorites-test-'));

function write(name, modes) {
  const filename = path.join(temporary, name);
  fs.writeFileSync(filename, YAML.stringify({ modes }));
  return filename;
}

function groups(filename, mode) {
  const document = YAML.parse(fs.readFileSync(filename, 'utf8'));
  return document.modes.find((entry) => entry[mode])[mode].talkgroups;
}

try {
  const active = write('active.yml', [
    { DMR: { talkgroups: [{ alias: 'My existing DMR', tgid: '123' }] } },
    { YSF: { talkgroups: [{ alias: 'My existing YSF', tgid: '456' }] } }
  ]);
  const bm = path.join(temporary, 'bm.yml');
  const tgif = path.join(temporary, 'tgif.yml');
  fs.copyFileSync(path.join(root, 'presets/tg_alias.BM.yml'), bm);
  fs.copyFileSync(path.join(root, 'presets/tg_alias.TGIF.yml'), tgif);
  const protectedBm = write('protected-bm.yml', [
    { DMR: { talkgroups: [{ alias: 'Saved BM', tgid: '3100' }] } }
  ]);

  childProcess.execFileSync(process.execPath, [
    path.join(root, 'installer/merge-favorites.js'),
    '--active', active,
    '--bm', bm,
    '--tgif', tgif,
    '--network', 'tgif',
    '--protected-bm', protectedBm
  ]);

  assert.deepStrictEqual(groups(bm, 'DMR'), [{ alias: 'Saved BM', tgid: '3100' }]);
  assert.deepStrictEqual(groups(tgif, 'DMR'), [{ alias: 'My existing DMR', tgid: '123' }]);
  assert.deepStrictEqual(groups(bm, 'YSF'), [{ alias: 'My existing YSF', tgid: '456' }]);
  assert.deepStrictEqual(groups(tgif, 'YSF'), [{ alias: 'My existing YSF', tgid: '456' }]);
  assert.ok(groups(bm, 'STFU').length > 0, 'repository-only modes must remain available');
  process.stdout.write('Favorites migration tests passed.\n');
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
