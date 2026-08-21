<div align="center">

# 📻 DVS Mode Switcher Enhanced

### A simple web interface for DVSwitch mode, talkgroup and DMR-network control

[![Version](https://img.shields.io/badge/version-1.1.0--rc7-2563eb?style=for-the-badge)](CHANGELOG.md)
[![Platform](https://img.shields.io/badge/platform-ASL%203%20%7C%20Debian-0f766e?style=for-the-badge)](#-requirements)
[![Node.js](https://img.shields.io/badge/Node.js-18%2B-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)](#-requirements)
[![License](https://img.shields.io/badge/license-LGPL--3.0-blue?style=for-the-badge)](LICENSE)

**Production web interface:** `http://YOUR-NODE-IP:3000`

</div>

---

## ✨ Features

| Feature | Description |
|---|---|
| 🎛️ Mode control | Change DVSwitch modes and tune talkgroups from a browser. |
| 🔀 DMR network selector | Switch between TGIF and BrandMeister without treating them as separate DVSwitch modes. |
| 🟢 Live network status | Shows which DMR backend is currently active. |
| ⭐ Matched favorites | Uses a separate DMR favorites list for TGIF and BrandMeister. |
| 🔇 STFU support | Includes STFU mode and favorites when STFU is installed. |
| 🔐 Restricted switching | Runs the website as `asl` and permits only the fixed BM, TGIF and status helper actions through sudo. |
| 🧭 Configuration discovery | Reads the existing DVSwitch callsign, IDs, network settings and available credentials. |
| 🪪 ID synchronization | Keeps the seven-digit DMR ID and nine-digit Analog_Bridge repeater ID consistent. |
| 🧱 Firewall setup | Preserves or adds TCP port 3000 automatically for firewalld or UFW. |
| 💾 Backup and rollback | Backs up affected files and restores them automatically if installation or network switching fails. |

---

## 🖥️ Requirements

- ASL 3 or a compatible Debian DVSwitch system using systemd
- An existing, working DVSwitch installation
- `/opt/MMDVM_Bridge/MMDVM_Bridge.ini`
- `/opt/MMDVM_Bridge/dvswitch.sh`
- `/opt/Analog_Bridge/Analog_Bridge.ini`
- Linux user and group `asl`
- Web-server account `www-data`
- Node.js 18 or newer; the installer installs Node.js when needed
- Access to the BrandMeister Hotspot Security and TGIF secured-connection passwords if they cannot be discovered from the existing configuration

> [!IMPORTANT]
> This installer installs **DVS Mode Switcher**. It does not install or remove the underlying DVSwitch packages.

---

## 🚀 First installation

Log into the DVSwitch server and copy/paste this single command:

```bash
cd /home/asl && git clone https://github.com/ke2hni/dvs-mode-switcher-mods.git && cd dvs-mode-switcher-mods && sudo ./install-dvswitch-mode-switcher.sh
```

The installer detects a first installation and guides the user through the required information. Password entries are hidden.

### Information the installer may request

- Seven-digit DMR/CCS7 ID when the existing value is invalid or still a placeholder
- Five-digit NXDN ID, if the user has one
- Two-digit Analog_Bridge SSID only when it cannot be discovered
- BrandMeister Hotspot Security password when it cannot be discovered
- TGIF secured-connection password when it cannot be discovered
- Initial DMR network: `bm` or `tgif`

> [!NOTE]
> The BrandMeister credential is the **Hotspot Security** password, not the BrandMeister website-account password. The TGIF credential is the **secured-connection** password.

---

## 🔄 Updating

Run this single command:

```bash
cd /home/asl/dvs-mode-switcher-mods && git pull --ff-only && sudo ./install-dvswitch-mode-switcher.sh
```

An upgrade preserves the production configuration, available credentials and favorites. The installer asks whether the active DMR favorites belong to `bm` or `tgif`, assigns that DMR list to the selected network, and copies existing non-DMR favorites to both network presets.

---

## 🧹 Clean reinstall

Run this only when previous DVS Mode Switcher settings and favorites should be replaced with freshly generated network presets and repository defaults:

```bash
cd /home/asl/dvs-mode-switcher-mods && git pull --ff-only && sudo ./install-dvswitch-mode-switcher.sh --clean
```

> [!WARNING]
> `--clean` ignores previous DVS Mode Switcher settings, protected presets and customized favorites. It still reads the live DVSwitch configuration and does not reinstall DVSwitch itself.

---

## 🧭 Installation modes

| Mode | How it is selected | Behavior |
|---|---|---|
| 🆕 First | Automatic when no Mode Switcher is detected | Installs DVS Mode Switcher while reading the existing DVSwitch configuration. |
| ⬆️ Upgrade | Automatic when `/opt/dvswitch_mode_switcher/package.json` exists | Preserves production configuration, credentials and favorites while applying updates. |
| 🧹 Clean | Explicit `--clean` option | Rebuilds DVS Mode Switcher settings and presets from the live DVSwitch INI and repository defaults. |

All three modes require an existing DVSwitch installation.

---

## ⚙️ What the installer does

1. Confirms that DVSwitch is installed and detects first, upgrade or clean mode.
2. Reads the callsign, DMR ID, NXDN ID and DMR network from `MMDVM_Bridge.ini`.
3. Reads the DMR ID and two-digit SSID information from `Analog_Bridge.ini`.
4. Requests only information that is missing, invalid or still uses a placeholder.
5. Generates protected BM and TGIF presets locally; no credential-bearing INI is stored in this repository.
6. Installs dependencies and prepares the production application on port 3000.
7. Backs up the existing application and every affected system or DVSwitch file before replacing it.
8. Installs the restricted helper, systemd service, sudo policy and synchronized Analog_Bridge IDs when needed.
9. Activates the selected DMR network and its matching favorites.
10. Preserves or adds TCP port 3000 when firewalld or UFW is active.
11. Verifies the website, active network, favorites, file permissions and bridge-service health.

Passwords are hidden while entered and are never printed by the installer or included in its summary.

---

## 🪪 DMR and NXDN IDs

| Setting | Format | Installed location |
|---|---|---|
| Base DMR/CCS7 ID | Seven digits | `MMDVM_Bridge.ini` `[General] Id` and `Analog_Bridge.ini` `gatewayDmrId` |
| Analog_Bridge repeater ID | Seven-digit DMR ID plus two-digit SSID | `Analog_Bridge.ini` `repeaterID` |
| NXDN ID | Optional five-digit ID | `MMDVM_Bridge.ini` `[NXDN] Id` |

The installer preserves a valid existing two-digit SSID. If the base DMR ID must be corrected, it synchronizes `gatewayDmrId` and `repeaterID` while backing up `Analog_Bridge.ini` for rollback.

---

## 🧱 Firewall handling

When firewalld or UFW is active, the installer checks TCP port 3000 automatically:

- An existing allowance is preserved.
- A missing allowance is added and verified.
- firewalld receives both runtime and permanent rules in the active zone.
- A rule added by a failed installation is removed during rollback.
- No separate firewall command is required from the user.

---

## ✅ Verify the installation

### Service status

```bash
sudo systemctl status dvswitch_mode_switcher.service --no-pager
```

### Production webpage

```bash
curl -I http://127.0.0.1:3000/
```

### Active DMR network

```bash
curl -s http://127.0.0.1:3000/dmr-network/status && echo
```

### Recent service log

```bash
sudo journalctl -u dvswitch_mode_switcher.service -n 50 --no-pager
```

---

## 📦 Installed and managed locations

| Item | Location |
|---|---|
| Application | `/opt/dvswitch_mode_switcher/` |
| Production configuration | `/opt/dvswitch_mode_switcher/configs/config.yml` |
| Active favorites | `/opt/dvswitch_mode_switcher/configs/tg_alias.yml` |
| Service | `/etc/systemd/system/dvswitch_mode_switcher.service` |
| Restricted DMR helper | `/usr/local/sbin/dvswitch-dmr-network-prod` |
| Restricted sudo policy | `/etc/sudoers.d/dvswitch-mode-switcher` |
| Protected network presets | `/etc/dvswitch-mode-switcher/presets/` |
| Installation and switch backups | `/var/backups/dvswitch-mode-switcher/` |
| GitHub checkout used for updates | `/home/asl/dvs-mode-switcher-mods/` |
| Existing live MMDVM configuration | `/opt/MMDVM_Bridge/MMDVM_Bridge.ini` |
| Existing Analog_Bridge identity configuration | `/opt/Analog_Bridge/Analog_Bridge.ini` |
| TCP 3000 allowance, when needed | Active firewalld zone or UFW |

The web application runs as `asl`, not root. It may invoke only the restricted helper with the exact arguments `bm`, `tgif` or `status`.

---

## 🔀 DMR network switching

No credential-bearing MMDVM INI files are stored in this repository. Both protected presets are generated locally from the working live INI.

The BM and TGIF MMDVM presets are otherwise identical and differ only in:

- `[DMR Network] Address`
- `[DMR Network] Password`

| File type | Ownership and mode |
|---|---|
| Protected BM/TGIF MMDVM presets | `root:root 0600` |
| Active live `MMDVM_Bridge.ini` | `root:www-data 0640` |
| Favorites presets | `root:root 0644` |
| Active favorites | `asl:asl 0644` |

Selecting TGIF or BrandMeister installs the matching MMDVM preset and favorites together, restarts Analog_Bridge and MMDVM_Bridge, returns DVSwitch to DMR mode, and verifies service health and dashboard access. Both files are rolled back if switching fails.

---

## ⭐ Favorites

- `presets/tg_alias.BM.yml` contains BrandMeister DMR favorites.
- `presets/tg_alias.TGIF.yml` contains TGIF DMR favorites.
- STFU, YSF, P25, D-STAR and NXDN favorites are synchronized between both presets.

Before installation, favorites can be edited in the repository's two files above. After installation, edit the active network presets at:

- `/etc/dvswitch-mode-switcher/presets/tg_alias.BM.yml`
- `/etc/dvswitch-mode-switcher/presets/tg_alias.TGIF.yml`

Switching networks applies the corresponding favorites file.

---

## ♻️ Backup and rollback

The installer reports its timestamped backup directory under:

```text
/var/backups/dvswitch-mode-switcher/
```

If installation verification fails, it automatically attempts to restore the previous production application, affected configuration files, system integration and any firewall rule changed by that installation.

Network switching also creates timestamped backups of the live MMDVM INI and active favorites before changing them.

---

## 📊 Validated status

- ✅ First installation tested on Raspberry Pi 5, ARM64 and Debian 13
- ✅ Upgrade installation tested
- ✅ Clean reinstall tested
- ✅ TGIF and BrandMeister switching tested
- ✅ Network-specific favorites tested
- ✅ Seven-digit/nine-digit DMR ID synchronization tested
- ✅ firewalld TCP 3000 creation and persistence tested
- ✅ Dashboard-readable live INI permissions tested
- ✅ Reboot persistence tested
- ✅ Production service verified with zero restarts

---

## 📜 Credits and license

Based on the original **DVS Mode Switcher** by Caleb (KO4UYJ).

Licensed under **LGPL-3.0-only**. See [LICENSE](LICENSE).

<img width="1600" height="852" alt="Screenshot 2026-08-20 234650" src="https://github.com/user-attachments/assets/408c2c91-ad78-4550-b9f4-49434fe4bd5e" />
<img width="1600" height="852" alt="Screenshot 2026-08-20 234722" src="https://github.com/user-attachments/assets/8d9ce569-0422-40d0-b935-565937eb0f7f" />
<img width="1600" height="852" alt="Screenshot 2026-08-20 234731" src="https://github.com/user-attachments/assets/79b46496-dd73-4d06-a4cf-4af627eef8ca" />
<img width="1600" height="852" alt="Screenshot 2026-08-20 234745" src="https://github.com/user-attachments/assets/0e933fd3-9521-41c7-b910-df2ac9ede55f" />
