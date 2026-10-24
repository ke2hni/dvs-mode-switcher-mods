#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR=/opt/dvswitch_mode_switcher
LIVE_INI=/opt/MMDVM_Bridge/MMDVM_Bridge.ini
ANALOG_INI=/opt/Analog_Bridge/Analog_Bridge.ini
CONFIG_DIR=/etc/dvswitch-mode-switcher
PRESET_DIR=$CONFIG_DIR/presets
HELPER=/usr/local/sbin/dvswitch-dmr-network-prod
SERVICE=dvswitch_mode_switcher.service
UNIT_FILE=/etc/systemd/system/$SERVICE
SUDOERS_FILE=/etc/sudoers.d/dvswitch-mode-switcher
BACKUP_BASE=/var/backups/dvswitch-mode-switcher

log() { printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
usage() {
    printf 'Usage: sudo ./%s [--check | --yes]\n' "${0##*/}"
    printf '  --check  Show what would be removed or restored without changing files.\n'
    printf '  --yes    Run without the confirmation prompt.\n'
}

CHECK_ONLY=0
ASSUME_YES=0
while (($#)); do
    case "$1" in
        --check) CHECK_ONLY=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown option: $1" ;;
    esac
    shift
done

[[ $EUID -eq 0 ]] || die "Run with sudo: sudo ./${0##*/}"
command -v systemctl >/dev/null || die "systemd is required."

manifest_value() {
    local file=$1 key=$2
    [[ -f "$file" ]] || return 0
    awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$file"
}

valid_snapshot() {
    local dir=$1 manifest="$1/manifest" fmt
    [[ -d "$dir" && ! -L "$dir" && "${dir##*/}" == install-* && -f "$manifest" ]] || return 1
    fmt=$(manifest_value "$manifest" backup_format)
    [[ $fmt == 1 || $fmt == 2 ]] || return 1
    [[ -f "$dir/live-MMDVM_Bridge.ini" && -f "$dir/live-Analog_Bridge.ini" ]] || return 1
    [[ -e "$dir/application" || -e "$dir/application.absent" ]] || return 1
    [[ -e "$dir/helper" || -e "$dir/helper.absent" ]] || return 1
    [[ -e "$dir/unit" || -e "$dir/unit.absent" ]] || return 1
    [[ -e "$dir/sudoers" || -e "$dir/sudoers.absent" ]] || return 1
}

SNAPSHOT=
if [[ -d "$BACKUP_BASE" ]]; then
    while IFS= read -r candidate; do
        if valid_snapshot "$candidate"; then SNAPSHOT=$candidate; break; fi
    done < <(find "$BACKUP_BASE" -mindepth 1 -maxdepth 1 -type d -name 'install-*' -printf '%f\n' | sort -r | sed "s#^#$BACKUP_BASE/#")
fi

FW_BACKEND=none
FW_ZONE=
if [[ -n $SNAPSHOT ]]; then
    FW_BACKEND=$(manifest_value "$SNAPSHOT/manifest" firewall_backend)
    FW_ZONE=$(manifest_value "$SNAPSHOT/manifest" firewall_zone)
fi

printf 'DVS Mode Switcher uninstaller\n'
if [[ -n $SNAPSHOT ]]; then
    printf '  Restore point: %s\n' "${SNAPSHOT##*/}"
    printf '  Use snapshot for pre-install DVSwitch configuration and firewall state\n'
else
    printf '  Restore point: none; live bridge configuration and firewall rules will be preserved\n'
fi
printf '  Remove application: %s\n' "$APP_DIR"
printf '  Remove service: %s\n' "$UNIT_FILE"
printf '  Remove helper and sudo policy: %s, %s\n' "$HELPER" "$SUDOERS_FILE"
if [[ -n $SNAPSHOT ]]; then
    printf '  Restore live bridge configuration where DVSwitch directories exist\n'
    printf '  Remove the four Mode Switcher presets from %s\n' "$PRESET_DIR"
else
    printf '  Remove the four Mode Switcher presets from %s\n' "$PRESET_DIR"
fi
printf '  Keep installation and switch backups: %s\n' "$BACKUP_BASE"
printf '  Keep DVSwitch, Node.js, npm, Git and shared system dependencies\n'

if (( CHECK_ONLY )); then
    printf '\nCheck complete. No changes made.\n'
    exit 0
fi

if (( ! ASSUME_YES )); then
    [[ -r /dev/tty ]] || die "No interactive terminal; rerun with --yes after reviewing --check."
    printf '\nContinue with uninstall? [y/N] ' >/dev/tty
    read -r answer </dev/tty
    [[ $answer == y || $answer == Y || $answer == yes || $answer == YES ]] || { printf 'Cancelled.\n'; exit 0; }
fi

log "Stopping and disabling the Mode Switcher service"
systemctl disable --now "$SERVICE" >/dev/null 2>&1 || true

log "Removing application-specific files"
rm -rf -- "$APP_DIR"
rm -f -- "$HELPER" "$UNIT_FILE" "$SUDOERS_FILE"

if [[ -n $SNAPSHOT ]]; then
    log "Restoring pre-install DVSwitch configuration where directories remain"
    if [[ -d "${LIVE_INI%/*}" ]]; then
        cp -a -- "$SNAPSHOT/live-MMDVM_Bridge.ini" "$LIVE_INI"
    else
        printf '  Skipped MMDVM_Bridge.ini restore because %s is missing\n' "${LIVE_INI%/*}"
    fi
    if [[ -d "${ANALOG_INI%/*}" ]]; then
        cp -a -- "$SNAPSHOT/live-Analog_Bridge.ini" "$ANALOG_INI"
    else
        printf '  Skipped Analog_Bridge.ini restore because %s is missing\n' "${ANALOG_INI%/*}"
    fi
else
    log "Removing Mode Switcher presets"
fi

rm -f -- "$PRESET_DIR/MMDVM_Bridge.BM.ini" "$PRESET_DIR/MMDVM_Bridge.TGIF.ini" "$PRESET_DIR/tg_alias.BM.yml" "$PRESET_DIR/tg_alias.TGIF.yml"
rmdir -- "$PRESET_DIR" 2>/dev/null || true
rmdir -- "$CONFIG_DIR" 2>/dev/null || true

log "Restoring recorded firewall state when available"
case "$FW_BACKEND" in
    firewalld)
        if command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1 && [[ -n $SNAPSHOT ]]; then
            [[ -n $FW_ZONE ]] || FW_ZONE=$(firewall-cmd --get-default-zone)
            if [[ $(manifest_value "$SNAPSHOT/manifest" firewall_backend) == firewalld ]]; then
                if [[ $(manifest_value "$SNAPSHOT/manifest" firewall_runtime_3000) == yes ]]; then firewall-cmd --zone="$FW_ZONE" --add-port=3000/tcp >/dev/null; else firewall-cmd --zone="$FW_ZONE" --remove-port=3000/tcp >/dev/null 2>&1 || true; fi
                if [[ $(manifest_value "$SNAPSHOT/manifest" firewall_permanent_3000) == yes ]]; then firewall-cmd --permanent --zone="$FW_ZONE" --add-port=3000/tcp >/dev/null; else firewall-cmd --permanent --zone="$FW_ZONE" --remove-port=3000/tcp >/dev/null 2>&1 || true; fi
            fi
        fi
        ;;
    ufw)
        if [[ -n $SNAPSHOT ]] && command -v ufw >/dev/null && ufw status | head -n 1 | grep -q '^Status: active' && [[ $(manifest_value "$SNAPSHOT/manifest" firewall_backend) == ufw ]] && [[ $(manifest_value "$SNAPSHOT/manifest" firewall_permanent_3000) == yes ]]; then
            ufw status | grep -Eq '^3000/tcp[[:space:]]+ALLOW' || ufw allow 3000/tcp >/dev/null
        elif [[ -n $SNAPSHOT ]] && command -v ufw >/dev/null && ufw status | head -n 1 | grep -q '^Status: active' && [[ $(manifest_value "$SNAPSHOT/manifest" firewall_backend) == ufw ]] && ufw status | grep -Eq '^3000/tcp[[:space:]]+ALLOW'; then
            ufw --force delete allow 3000/tcp >/dev/null 2>&1 || true
        fi
        ;;
    none|'') ;;
    *) printf '  Warning: unknown firewall backend in snapshot (%s); firewall left unchanged\n' "$FW_BACKEND" ;;
esac

systemctl daemon-reload
systemctl reset-failed "$SERVICE" >/dev/null 2>&1 || true

printf '\nUninstall complete.\n'
if [[ -n $SNAPSHOT ]]; then
    printf '  Used snapshot for applicable restoration: %s\n' "$SNAPSHOT"
    printf '  Retained backups: %s\n' "$BACKUP_BASE"
else
    printf '  No installation snapshot was available. Live MMDVM/Analog_Bridge files and firewall rules were preserved.\n'
fi
