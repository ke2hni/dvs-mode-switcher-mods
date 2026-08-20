# Changelog

All notable modifications to this DVSwitch Mode Switcher fork are recorded here.

## 1.1.0-rc1 - 2026-08-20

- Prepared the tested development enhancements for an isolated production installation.
- Added a clean installer that discovers the existing DVSwitch configuration and generates protected BM/TGIF presets locally.
- Added password-safe credential discovery and prompting; credentials are never stored in the repository.
- Added production service, restricted sudo policy, backups, validation and rollback.
- Removed the development banner and port-3001 identification from production.

## 1.0.4-dev - 2026-08-19

- Added a TGIF/BrandMeister DMR network selector and active-network indicator.
- Added restricted server endpoints that call the validated DMR switching helper.
- Automatically load the matching DMR favorites after a network switch.
- Preserved the original mode and talkgroup switching routes.

## 1.0.3-dev - 2026-08-19

- Replaced the reboot-volatile transient development unit with a permanent systemd service.
- Enabled automatic startup of the isolated development interface on port 3001.
- Runtime verified the service with zero restarts while production remained available on port 3000.

## 1.0.2-dev - 2026-08-19

- Added STFU as a separate selectable mode.
- Added the original STFU/BrandMeister talkgroup list.
- Runtime tested mode switching and talkgroup changes through STFU.
- Confirmed Analog_Bridge displays STFU mode and talkgroup information correctly.

## 1.0.1-dev - 2026-08-18

- Added a prominent test-version banner to the development interface.
- Added test identification to the browser-tab title.
- Kept the development server isolated on port 3001.

## 1.0.0

- Original upstream DVSwitch Mode Switcher version at Git commit 1426a31.
