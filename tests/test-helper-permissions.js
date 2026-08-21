'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const helper = fs.readFileSync(path.resolve(__dirname, '../installer/dvswitch-dmr-network'), 'utf8');

assert.match(helper, /LIVE_INI_OWNER=root/);
assert.match(helper, /LIVE_INI_GROUP=www-data/);
assert.match(helper, /LIVE_INI_MODE=0640/);
assert.match(helper, /install -o "\$LIVE_INI_OWNER" -g "\$LIVE_INI_GROUP" -m "\$LIVE_INI_MODE" "\$INI_PRESET" "\$TEMP_INI"/);
assert.match(helper, /stat -c '%U:%G:%a'/);
assert.match(helper, /runuser -u "\$LIVE_INI_GROUP" -- test -r "\$LIVE_INI"/);
assert.doesNotMatch(helper, /install -o root -g root -m 0600 "\$INI_PRESET" "\$TEMP_INI"/);

process.stdout.write('Live INI permission regression test passed.\n');
