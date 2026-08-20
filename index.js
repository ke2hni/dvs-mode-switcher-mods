/**
 * This file is part of the DVSwitch Mode Switcher project.
 *
 * (c) 2024 Caleb <ko4uyj@gmail.com>
 *
 * For the full copyright and license information, see the
 * LICENSE file that was distributed with this source code.
 */

const yargs = require('yargs');
const path = require('path');
const Server = require('./modules/Server');

const argv = yargs
    .option('config', {
        alias: 'c',
        description: 'Path to the config file',
        type: 'string',
        demandOption: true
    })
    .help()
    .alias('help', 'h')
    .argv;

const configPath = path.resolve(argv.config);
const server = new Server(configPath);
server.start();