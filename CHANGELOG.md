# Changelog

All notable public releases of this DVSwitch Mode Switcher fork are recorded here.

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
