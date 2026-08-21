'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const installer = fs.readFileSync(path.resolve(__dirname, '../install-dvswitch-mode-switcher.sh'), 'utf8');

assert.match(installer, /ensure_firewall_port\(\)/);
assert.match(installer, /--query-port=3000\/tcp/);
assert.match(installer, /--add-port=3000\/tcp/);
assert.match(installer, /ufw allow 3000\/tcp/);
assert.match(installer, /FIREWALL_RULE_ADDED=1/);
assert.match(installer, /--remove-port=3000\/tcp/);
assert.match(installer, /ufw --force delete allow 3000\/tcp/);
assert.match(installer, /capture_firewall_state\(\)[\s\S]*?return 0\n\}/);

process.stdout.write('Firewall management regression test passed.\n');
