'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const installer = fs.readFileSync(path.resolve(__dirname, '../install-dvswitch-mode-switcher.sh'), 'utf8');

assert.match(installer, /BACKUP_ROOT="\/var\/backups\/dvswitch-mode-switcher\/install-\$STAMP"/);
assert.match(installer, /install -d -o root -g root -m 0700 "\$BACKUP_ROOT"/);
assert.match(installer, /save_or_mark_absent "\$APP_DIR" application/);
assert.match(installer, /save_or_mark_absent "\$HELPER" helper/);
assert.match(installer, /save_or_mark_absent "\$UNIT_FILE" unit/);
assert.match(installer, /save_or_mark_absent "\$SUDOERS_FILE" sudoers/);
assert.match(installer, /live-MMDVM_Bridge\.ini/);
assert.match(installer, /live-Analog_Bridge\.ini/);
assert.match(installer, /active-tg_alias\.yml/);
assert.match(installer, /\$BACKUP_ROOT\/manifest/);
assert.match(installer, /service_active=\$PREVIOUS_SERVICE_ACTIVE/);
assert.match(installer, /service_enabled=\$PREVIOUS_SERVICE_ENABLED/);
assert.match(installer, /chmod 0600 "\$BACKUP_ROOT\/manifest"/);
assert.match(installer, /BACKUP_COMPLETE=1/);
assert.match(installer, /if \(\( BACKUP_COMPLETE == 0 \)\)[\s\S]*?rm -rf -- "\$BACKUP_ROOT"/);

process.stdout.write('Durable pre-install backup regression test passed.\n');
