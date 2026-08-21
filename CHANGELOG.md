# Changelog

All notable public releases of this DVS Mode Switcher fork are recorded here.

## 1.1.0-rc10 - 2026-08-21

- Corrected firewall-state capture so an intentionally missing TCP 3000 rule is recorded as `no` instead of aborting installation under `set -e`.
- Applied the same missing-rule correction to pre-restore safety snapshots.
- Remove incomplete timestamped backup directories when installation fails before the backup manifest is completed.
- Avoid harmless firewalld `ALREADY_ENABLED` warnings by querying recorded rules before adding them during restore or automatic recovery.
- Added regression coverage for missing-firewall handling and incomplete-backup cleanup.

## 1.1.0-rc9 - 2026-08-21

- Added interactive and explicitly targeted permanent-backup restoration through `--restore`.
- Create and retain a complete pre-restore safety snapshot before changing the working installation.
- Restore the previous application or absence state, DVSwitch INIs, favorites, presets, helper, service and sudo integration.
- Restore recorded service enabled/running state and firewall TCP 3000 state.
- Automatically recover the pre-restore working state if restore verification fails.
- Keep RC8 backup compatibility while preserving the current firewall rule when legacy manifests have no recorded firewall state.
- Corrected remaining installer-output branding to DVS Mode Switcher.
- Added restore regression testing.
- Suppress transient connection messages during bounded post-restore website-readiness retries while retaining final failure detection.

## 1.1.0-rc8 - 2026-08-21

- Store a complete, permanent pre-install snapshot for first, upgrade and clean installations.
- Preserve the previous production application inside the timestamped backup directory, or record that it was previously absent.
- Record the prior installation mode and service active/enabled state in a root-only backup manifest.
- Keep successful-installation backups indefinitely for future recovery.
- Added a durable-backup regression test.

## 1.1.0-rc6 - 2026-08-20

- Automatically detect active firewalld or UFW host-firewall management.
- Preserve an existing TCP port 3000 allowance or add and verify it when missing.
- Select the active firewalld zone and configure both its runtime and permanent rules.
- Remove only a firewall rule added by the current installation if installation rolls back.
- Added a firewall-management regression test.

## 1.1.0-rc5 - 2026-08-20

- Synchronize Analog_Bridge `gatewayDmrId` with the validated seven-digit DMR ID.
- Build Analog_Bridge `repeaterID` from the seven-digit DMR ID plus its existing two-digit SSID.
- Ask for a two-digit SSID only when it cannot be discovered from a valid existing repeater ID.
- Back up, verify and roll back `Analog_Bridge.ini` with the other installation files.
- Added a DMR ID consistency regression test.

## 1.1.0-rc4 - 2026-08-20

- Simplified first-install, update and clean-reinstall instructions to one copy-and-paste command each.
- Use the normal `/home/asl/dvs-mode-switcher-mods` checkout instead of executing from a `noexec` `/tmp` filesystem.
- Corrected installer help and non-root guidance so `--clean` is shown only when deliberately requested.

## 1.1.0-rc3 - 2026-08-20

- Keep protected credential-bearing MMDVM presets at `root:root 0600`.
- Install the active live `MMDVM_Bridge.ini` as `root:www-data 0640` so the DVSwitch Dashboard can read it without exposing credentials to other users.
- Verify live INI ownership, mode and dashboard readability after every network switch and installation.
- Added a regression test preventing protected-preset permissions from being applied to the live INI again.

## 1.1.0-rc2 - 2026-08-20

- Added automatic clean, first-install and upgrade Mode Switcher paths.
- Added YAML-aware preservation of existing favorites during upgrades.
- Ask which DMR network owns the existing DMR favorites, while copying non-DMR favorites into both network presets.
- Preserve an existing production `config.yml` during upgrades while enforcing the restricted production helper path.
- Retain previously customized protected BM and TGIF DMR favorites when available.

## 1.1.0-rc1 - 2026-08-20

- Added STFU as a selectable mode with favorites.
- Added TGIF and BrandMeister network-selection buttons with a live active-network indicator.
- Added separate network-specific DMR favorite lists.
- Added restricted server endpoints for DMR network status and switching.
- Added a root-owned helper with configuration backup, validation, service checks and rollback.
- Added a clean installer that discovers the existing DVSwitch configuration and generates protected BM/TGIF presets locally.
- Added password-safe credential discovery and hidden prompting.
- Preserved the original mode and talkgroup switching routes.
- Added an `asl`-owned production service on port 3000 with narrowly restricted sudo permissions.
- Corrected staged application permissions for the unprivileged `asl` service account.
- Made local source cloning safe across different filesystems.
- Removed the unnecessary deprecated `dgram` npm dependency.

## 1.0.0

- Original upstream DVSwitch Mode Switcher at Git commit `1426a31`.
