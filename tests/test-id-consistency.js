'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const installer = fs.readFileSync(path.resolve(__dirname, '../install-dvs-mode-switcher.sh'), 'utf8');

assert.match(installer, /ANALOG_INI=\/opt\/Analog_Bridge\/Analog_Bridge\.ini/);
assert.match(installer, /EXPECTED_REPEATER_ID="\$\{DMR_ID\}\$\{ANALOG_SSID\}"/);
assert.match(installer, /replace_ini_value "\$TMP_DIR\/Analog_Bridge\.ini" AMBE_AUDIO gatewayDmrId/);
assert.match(installer, /replace_ini_value "\$TMP_DIR\/Analog_Bridge\.ini" AMBE_AUDIO repeaterID/);
assert.match(installer, /live-Analog_Bridge\.ini/);
assert.match(installer, /ini_get_scalar "\$ANALOG_INI" AMBE_AUDIO gatewayDmrId/);
assert.match(installer, /ini_get_scalar "\$ANALOG_INI" AMBE_AUDIO repeaterID/);

process.stdout.write('DMR ID consistency regression test passed.\n');
