# DVSwitch Mode Switcher Enhanced

This fork adds STFU favorites and a TGIF/BrandMeister selector to the original DVSwitch Mode Switcher. The selected DMR backend is read from the live `MMDVM_Bridge.ini`; it is not stored in browser memory.

## Requirements

- ASL 3 or Debian system using systemd
- An existing, working DVSwitch installation
- `/opt/MMDVM_Bridge/MMDVM_Bridge.ini`
- `/opt/MMDVM_Bridge/dvswitch.sh`
- User and group `asl`
- A BrandMeister Hotspot Security password
- A TGIF secured-connection password

The installer installs the Mode Switcher web application. It does not install, remove or reconfigure the underlying DVSwitch packages beyond generating the two DMR network presets from the working live INI.

## Clean production installation

Clone the repository and run:

```bash
sudo ./install-dvswitch-mode-switcher.sh --clean
```

`--clean` behaves as though Mode Switcher was never installed. It ignores earlier Mode Switcher program files and protected presets, while scanning the working DVSwitch INI for the callsign, DMR ID, NXDN ID, current DMR master and the credential belonging to the active backend.

The installer asks only for information it cannot recover. Password entry is hidden and must be confirmed. Use network connection credentials—not website login passwords.

The development installation at `/home/asl/dvswitch_mode_switcher-dev`, its systemd unit and port 3001 are not removed or replaced. Production uses `/opt/dvswitch_mode_switcher`, port 3000 and its own helper executable.

## What is installed

| Item | Location |
|---|---|
| Production application | `/opt/dvswitch_mode_switcher` |
| Production service | `/etc/systemd/system/dvswitch_mode_switcher.service` |
| Production helper | `/usr/local/sbin/dvswitch-dmr-network-prod` |
| Restricted sudo policy | `/etc/sudoers.d/dvswitch-mode-switcher` |
| Protected network presets | `/etc/dvswitch-mode-switcher/presets/` |
| Installation backups | `/var/backups/dvswitch-mode-switcher/` |

The Node.js process runs as `asl`, not root. It may invoke only the production helper with the exact arguments `bm`, `tgif` or `status`.

## Preset generation and privacy

No credential-bearing MMDVM INI file belongs in this repository. During installation, the script copies the live working INI twice and changes only these two keys inside `[DMR Network]`:

- `Address`
- `Password`

It normalizes those two fields and verifies that the resulting BM and TGIF files are otherwise identical. Generated presets are installed as `root:root` with mode `0600`.

The repository `.gitignore` excludes generated credential-bearing presets and common backup names.

## DMR favorites

- `presets/tg_alias.BM.yml` contains the BrandMeister DMR favorites.
- `presets/tg_alias.TGIF.yml` contains the TGIF DMR favorites.
- STFU, YSF, P25, D-STAR and NXDN sections are the same in both files.

Selecting a network installs its MMDVM preset and matching favorites together, restarts Analog_Bridge and MMDVM_Bridge, returns DVSwitch to DMR mode, and verifies the active address, favorites and service health. A failed switch rolls both files back.

## Repository

The production installer downloads this project from `https://github.com/ke2hni/dvs-mode-switcher-mods.git` when it is run outside a complete local source tree. The source can be overridden for testing with the `DVSWITCH_MODE_SWITCHER_REPO` environment variable.

Before committing, verify that no real MMDVM presets are staged:

```bash
git status --short
```

## Service checks

```bash
sudo systemctl status dvswitch_mode_switcher.service --no-pager
```

```bash
sudo journalctl -u dvswitch_mode_switcher.service -n 50 --no-pager
```

## Credits and license

Based on the original DVSwitch Mode Switcher by Caleb (KO4UYJ). The project remains licensed under LGPL-3.0-only; see `LICENSE`.
