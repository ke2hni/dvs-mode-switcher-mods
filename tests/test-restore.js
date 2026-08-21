'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const installer = fs.readFileSync(path.resolve(__dirname, '../install-dvswitch-mode-switcher.sh'), 'utf8');
const restore = fs.readFileSync(path.resolve(__dirname, '../installer/restore-backup'), 'utf8');

assert.match(installer, /--restore \[install-TIMESTAMP\]/);
assert.match(installer, /exec bash "\$SCRIPT_DIR\/installer\/restore-backup"/);
assert.match(installer, /firewall_backend=\$PREVIOUS_FIREWALL_BACKEND/);
assert.match(installer, /firewall_runtime_3000=\$PREVIOUS_FIREWALL_RUNTIME/);
assert.match(installer, /firewall_permanent_3000=\$PREVIOUS_FIREWALL_PERMANENT/);
assert.match(restore, /restore-safety-\$STAMP/);
assert.match(restore, /save_or_mark_absent "\$APP_DIR" "\$SAFETY\/application"/);
assert.match(restore, /restore_item "\$snapshot" application "\$APP_DIR"/);
assert.match(restore, /restore_item "\$snapshot" live-MMDVM_Bridge\.ini "\$LIVE_INI"/);
assert.match(restore, /restore_item "\$snapshot" live-Analog_Bridge\.ini "\$ANALOG_INI"/);
assert.match(restore, /restore_item "\$snapshot" presets "\$PRESET_DIR"/);
assert.match(restore, /apply_firewall_state "\$snapshot"/);
assert.match(restore, /Restore failed; attempting to recover the pre-restore working state/);
assert.match(restore, /apply_snapshot "\$SAFETY" 1/);
assert.match(restore, /legacy backup has no recorded state; current TCP 3000 rule preserved/);
assert.doesNotMatch(restore, /Password/);

process.stdout.write('Permanent restore regression test passed.\n');
