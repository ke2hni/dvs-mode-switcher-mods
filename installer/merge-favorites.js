#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const YAML = require('yaml');

function fail(message) {
  process.stderr.write(`Favorites migration failed: ${message}\n`);
  process.exit(1);
}

function parseArguments(argv) {
  const options = {};
  for (let index = 0; index < argv.length; index += 2) {
    const name = argv[index];
    const value = argv[index + 1];
    if (!name || !name.startsWith('--') || value === undefined) fail('invalid command line');
    options[name.slice(2)] = value;
  }
  for (const required of ['active', 'bm', 'tgif', 'network']) {
    if (!options[required]) fail(`--${required} is required`);
  }
  if (!['bm', 'tgif'].includes(options.network)) fail('--network must be bm or tgif');
  return options;
}

function loadModes(filename, required = true) {
  if (!filename || !fs.existsSync(filename)) {
    if (required) fail(`missing file: ${filename}`);
    return null;
  }
  let document;
  try {
    document = YAML.parse(fs.readFileSync(filename, 'utf8'));
  } catch (error) {
    fail(`cannot parse ${filename}: ${error.message}`);
  }
  if (!document || !Array.isArray(document.modes)) fail(`${filename} does not contain a modes list`);
  const modes = new Map();
  for (const entry of document.modes) {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry) || Object.keys(entry).length !== 1) {
      fail(`${filename} contains an invalid mode entry`);
    }
    const name = Object.keys(entry)[0];
    const value = entry[name];
    if (!value || !Array.isArray(value.talkgroups)) fail(`${filename} mode ${name} has no talkgroups list`);
    modes.set(name, structuredClone(value));
  }
  return modes;
}

function replaceMode(target, source, name) {
  if (source && source.has(name)) target.set(name, structuredClone(source.get(name)));
}

function count(modes, name) {
  return modes.has(name) ? modes.get(name).talkgroups.length : 0;
}

function saveModes(filename, modes) {
  const output = { modes: Array.from(modes, ([name, value]) => ({ [name]: value })) };
  const temporary = `${filename}.tmp-${process.pid}`;
  fs.writeFileSync(temporary, YAML.stringify(output), { mode: 0o644 });
  fs.renameSync(temporary, filename);
}

const options = parseArguments(process.argv.slice(2));
const active = loadModes(options.active);
const bm = loadModes(options.bm);
const tgif = loadModes(options.tgif);
const protectedBm = loadModes(options['protected-bm'], false);
const protectedTgif = loadModes(options['protected-tgif'], false);

// Retain previously customized DMR lists for both protected network presets first.
replaceMode(bm, protectedBm, 'DMR');
replaceMode(tgif, protectedTgif, 'DMR');

// The active DMR list belongs only to the network selected by the user.
replaceMode(options.network === 'bm' ? bm : tgif, active, 'DMR');

// All other existing mode lists are shared by both network presets.
for (const name of active.keys()) {
  if (name === 'DMR') continue;
  replaceMode(bm, active, name);
  replaceMode(tgif, active, name);
}

saveModes(options.bm, bm);
saveModes(options.tgif, tgif);

process.stdout.write(`  Existing DMR favorites: ${count(active, 'DMR')} assigned to ${options.network}\n`);
for (const name of active.keys()) {
  if (name !== 'DMR') process.stdout.write(`  Existing ${name} favorites: ${count(active, name)} copied to both presets\n`);
}
