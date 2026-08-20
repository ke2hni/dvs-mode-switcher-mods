/**
 * This file is part of the DVSwitch Mode Switcher project.
 *
 * (c) 2024 Caleb <ko4uyj@gmail.com>
 *
 * For the full copyright and license information, see the
 * LICENSE file that was distributed with this source code.
 */

const Talkgroup = require("./Talkgroup");

class Mode {
    constructor(name, talkgroups = []) {
        this.name = name;
        this.talkgroups = talkgroups.map(tg => new Talkgroup(tg.alias, tg.tgid));
    }

    static fromYAML(yamlData) {
        return yamlData.modes.map(mode => {
            const modeName = Object.keys(mode)[0];
            return new Mode(modeName, mode[modeName].talkgroups);
        });
    }
}

module.exports = Mode;