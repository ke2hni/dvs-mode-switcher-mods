#!/usr/bin/env bash
set -Eeuo pipefail

# Installs DVS Mode Switcher. It does not remove or reinstall DVSwitch.
APP_DIR=/opt/dvswitch_mode_switcher
LIVE_INI=/opt/MMDVM_Bridge/MMDVM_Bridge.ini
ANALOG_INI=/opt/Analog_Bridge/Analog_Bridge.ini
DVSWITCH_INI=/opt/MMDVM_Bridge/DVSwitch.ini
DVSWITCH_SH=/opt/MMDVM_Bridge/dvswitch.sh
PRESET_DIR=/etc/dvswitch-mode-switcher/presets
HELPER=/usr/local/sbin/dvswitch-dmr-network-prod
SERVICE=dvswitch_mode_switcher.service
UNIT_FILE=/etc/systemd/system/dvswitch_mode_switcher.service
SUDOERS_FILE=/etc/sudoers.d/dvswitch-mode-switcher
REPO_URL="${DVSWITCH_MODE_SWITCHER_REPO:-https://github.com/ke2hni/dvs-mode-switcher-mods.git}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="/var/backups/dvswitch-mode-switcher/install-$STAMP"
CLEAN=0
INSTALL_MODE=
EXISTING_FAVORITES_NETWORK=
SWAPPED=0
INSTALL_COMPLETE=0
BACKUP_COMPLETE=0
OLD_APP=
STAGE=
TMP_DIR=
FIREWALL_BACKEND=none
FIREWALL_ZONE=
FIREWALL_RULE_ADDED=0
PREVIOUS_SERVICE_ACTIVE=unknown
PREVIOUS_SERVICE_ENABLED=unknown
PREVIOUS_FIREWALL_BACKEND=none
PREVIOUS_FIREWALL_ZONE=
PREVIOUS_FIREWALL_RUNTIME=no
PREVIOUS_FIREWALL_PERMANENT=no

log() { printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
usage() { printf 'Usage: sudo ./%s [--clean | --restore [install-TIMESTAMP]]\n' "${0##*/}"; printf '  No option  Automatically perform a first installation or safe upgrade.\n'; printf '  --clean    Replace previous Mode Switcher settings with a fresh production copy.\n'; printf '  --restore  Interactively select, or explicitly name, a permanent backup to restore.\n'; }

case "${1:-}" in
    --clean) CLEAN=1 ;;
    --restore) [[ $# -le 2 ]] || { usage >&2; exit 1; }; exec bash "$SCRIPT_DIR/installer/restore-backup" "${2:-}" ;;
    "") ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "Unknown option: $1" ;;
esac

[[ ${EUID} -eq 0 ]] || die "Run with sudo: sudo ./${0##*/}"
[[ -r "$LIVE_INI" ]] || die "DVSwitch is not configured: $LIVE_INI is missing or unreadable."
[[ -r "$ANALOG_INI" ]] || die "DVSwitch is not configured: $ANALOG_INI is missing or unreadable."
[[ -x "$DVSWITCH_SH" ]] || die "DVSwitch control script is missing: $DVSWITCH_SH"
getent passwd asl >/dev/null || die "Required ASL user 'asl' does not exist."
getent passwd www-data >/dev/null || die "Required dashboard account 'www-data' does not exist."
command -v systemctl >/dev/null || die "systemd is required."

if (( CLEAN )); then
    INSTALL_MODE=clean
elif [[ -d "$APP_DIR" && -f "$APP_DIR/package.json" ]]; then
    INSTALL_MODE=upgrade
else
    INSTALL_MODE=first
fi

umask 077
TMP_DIR="$(mktemp -d /tmp/dvswitch-mode-switcher-install.XXXXXX)"

cleanup() {
    if [[ -n "${TMP_DIR:-}" && "$TMP_DIR" == /tmp/dvswitch-mode-switcher-install.* && -d "$TMP_DIR" ]]; then rm -rf -- "$TMP_DIR"; fi
    if (( INSTALL_COMPLETE == 0 )) && [[ -n "${STAGE:-}" && "$STAGE" == /opt/.dvswitch-mode-switcher-stage-* && -d "$STAGE" ]]; then rm -rf -- "$STAGE"; fi
}

restore_file() {
    local backup_name="$1" destination="$2"
    if [[ -e "$BACKUP_ROOT/$backup_name" ]]; then cp -a "$BACKUP_ROOT/$backup_name" "$destination"; elif [[ -e "$BACKUP_ROOT/$backup_name.absent" ]]; then rm -f -- "$destination"; fi
}

rollback() {
    local rc=$?
    trap - ERR
    if (( SWAPPED )); then
        systemctl stop "$SERVICE" >/dev/null 2>&1 || true
        [[ ! -d "$APP_DIR" ]] || mv "$APP_DIR" "${APP_DIR}.failed-$STAMP" || true
        [[ -z "$OLD_APP" || ! -d "$OLD_APP" ]] || mv "$OLD_APP" "$APP_DIR" || true
        restore_file helper "$HELPER"
        restore_file unit "$UNIT_FILE"
        restore_file sudoers "$SUDOERS_FILE"
        if (( FIREWALL_RULE_ADDED )); then
            case "$FIREWALL_BACKEND" in
                firewalld) firewall-cmd --zone="$FIREWALL_ZONE" --remove-port=3000/tcp >/dev/null 2>&1 || true; firewall-cmd --permanent --zone="$FIREWALL_ZONE" --remove-port=3000/tcp >/dev/null 2>&1 || true ;;
                ufw) ufw --force delete allow 3000/tcp >/dev/null 2>&1 || true ;;
            esac
        fi
        if [[ -d "$BACKUP_ROOT/presets" ]]; then install -d -o root -g root -m 0755 "$PRESET_DIR"; cp -a "$BACKUP_ROOT/presets/." "$PRESET_DIR/" || true; elif [[ -e "$BACKUP_ROOT/presets.absent" ]]; then rm -rf -- "$PRESET_DIR"; fi
        [[ ! -e "$BACKUP_ROOT/live-MMDVM_Bridge.ini" ]] || cp -a "$BACKUP_ROOT/live-MMDVM_Bridge.ini" "$LIVE_INI"
        [[ ! -e "$BACKUP_ROOT/live-Analog_Bridge.ini" ]] || cp -a "$BACKUP_ROOT/live-Analog_Bridge.ini" "$ANALOG_INI"
        if [[ -e "$BACKUP_ROOT/active-tg_alias.yml" && -d "$APP_DIR/configs" ]]; then install -o asl -g asl -m 0644 "$BACKUP_ROOT/active-tg_alias.yml" "$APP_DIR/configs/tg_alias.yml"; fi
        systemctl restart analog_bridge.service mmdvm_bridge.service >/dev/null 2>&1 || true
        systemctl daemon-reload >/dev/null 2>&1 || true
        systemctl enable --now "$SERVICE" >/dev/null 2>&1 || true
    fi
    if (( BACKUP_COMPLETE == 0 )) && [[ "$BACKUP_ROOT" == /var/backups/dvswitch-mode-switcher/install-* && -d "$BACKUP_ROOT" ]]; then rm -rf -- "$BACKUP_ROOT"; fi
    cleanup
    printf '\nInstallation failed. Previous production files were restored where available.\n' >&2
    exit "$rc"
}

trap cleanup EXIT
trap rollback ERR

ini_get() {
    local file="$1" section="$2" key="$3"
    awk -v wanted_section="$section" -v wanted_key="$key" '
        function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
        /^[[:space:]]*\[[^]]+\][[:space:]]*$/ { current=$0; gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", current); in_section=(current==wanted_section); next }
        in_section && index($0, "=") { name=substr($0,1,index($0,"=")-1); if (trim(name)==wanted_key) { value=substr($0,index($0,"=")+1); print trim(value); exit } }
    ' "$file"
}

ini_get_scalar() {
    local value
    value="$(ini_get "$1" "$2" "$3")"
    value="${value%%[[:space:]];*}"
    value="${value%%[[:space:]]#*}"
    printf '%s\n' "$value" | tr -d '[:space:]'
}

classify_address() {
    case "$1" in
        tgif.network) printf 'tgif\n' ;;
        *.master.brandmeister.network|*.brandmeister.network|*.repeater.net) printf 'bm\n' ;;
        *) printf 'unknown\n' ;;
    esac
}

credential_usable() { [[ -n "$1" && "$1" != passw0rd && "$1" != CHANGE-ME && "$1" != __*__ ]]; }

prompt_secret() {
    local label="$1" first second
    while true; do
        read -rsp "Enter $label: " first </dev/tty; printf '\n' >/dev/tty
        [[ -n "$first" ]] || { printf 'The password cannot be blank.\n' >/dev/tty; continue; }
        read -rsp "Confirm $label: " second </dev/tty; printf '\n' >/dev/tty
        [[ "$first" == "$second" ]] || { printf 'Passwords did not match; try again.\n' >/dev/tty; continue; }
        REPLY_SECRET="$first"; first= second=; return 0
    done
}

prompt_with_default() { local prompt="$1" default="$2" answer; read -rp "$prompt [$default]: " answer </dev/tty; printf '%s\n' "${answer:-$default}"; }
write_value_file() { local path="$1" value="$2"; printf '%s\n' "$value" >"$path"; chmod 0600 "$path"; }

replace_ini_value() {
    local input="$1" section="$2" key="$3" value_file="$4" output="$5"
    awk -v wanted_section="$section" -v wanted_key="$key" -v value_file="$value_file" '
        BEGIN { if ((getline replacement < value_file)<1) exit 20; close(value_file) }
        function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
        /^[[:space:]]*\[[^]]+\][[:space:]]*$/ { current=$0; gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", current); in_section=(current==wanted_section) }
        in_section && index($0,"=") { name=substr($0,1,index($0,"=")-1); if (trim(name)==wanted_key) { print wanted_key "=" replacement; found=1; next } }
        { print }
        END { if (!found) exit 22 }
    ' "$input" >"$output"
    chmod 0600 "$output"
}

generate_preset() {
    local source="$1" output="$2" address_file="$3" password_file="$4"
    awk -v address_file="$address_file" -v password_file="$password_file" '
        BEGIN { if ((getline address < address_file)<1) exit 20; close(address_file); if ((getline password < password_file)<1) exit 21; close(password_file) }
        /^[[:space:]]*\[[^]]+\][[:space:]]*$/ { section=$0; gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", section); in_dmr=(section=="DMR Network") }
        in_dmr && /^[[:space:]]*Address[[:space:]]*=/ { print "Address=" address; found_address=1; next }
        in_dmr && /^[[:space:]]*Password[[:space:]]*=/ { print "Password=" password; found_password=1; next }
        { print }
        END { if (!found_address || !found_password) exit 22 }
    ' "$source" >"$output"
    chmod 0600 "$output"
}

normalized_ini() {
    awk '
        /^[[:space:]]*\[[^]]+\][[:space:]]*$/ { section=$0; gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", section); in_dmr=(section=="DMR Network") }
        in_dmr && /^[[:space:]]*Address[[:space:]]*=/ { print "Address=__NETWORK_ADDRESS__"; next }
        in_dmr && /^[[:space:]]*Password[[:space:]]*=/ { print "Password=__NETWORK_PASSWORD__"; next }
        { print }
    ' "$1"
}

save_or_mark_absent() { local source="$1" backup_name="$2"; if [[ -e "$source" ]]; then cp -a "$source" "$BACKUP_ROOT/$backup_name"; else : >"$BACKUP_ROOT/$backup_name.absent"; fi; }

capture_firewall_state() {
    PREVIOUS_FIREWALL_BACKEND=none; PREVIOUS_FIREWALL_ZONE=; PREVIOUS_FIREWALL_RUNTIME=no; PREVIOUS_FIREWALL_PERMANENT=no
    if command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then
        PREVIOUS_FIREWALL_BACKEND=firewalld
        PREVIOUS_FIREWALL_ZONE="$(firewall-cmd --get-active-zones | awk '$1 != "interfaces:" && $1 != "sources:" { print $1; exit }')"
        [[ -n "$PREVIOUS_FIREWALL_ZONE" ]] || PREVIOUS_FIREWALL_ZONE="$(firewall-cmd --get-default-zone)"
        firewall-cmd --zone="$PREVIOUS_FIREWALL_ZONE" --query-port=3000/tcp >/dev/null 2>&1 && PREVIOUS_FIREWALL_RUNTIME=yes
        firewall-cmd --permanent --zone="$PREVIOUS_FIREWALL_ZONE" --query-port=3000/tcp >/dev/null 2>&1 && PREVIOUS_FIREWALL_PERMANENT=yes
    elif command -v ufw >/dev/null && ufw status | head -n 1 | grep -q '^Status: active'; then
        PREVIOUS_FIREWALL_BACKEND=ufw
        if ufw status | grep -Eq '^3000/tcp[[:space:]]+ALLOW'; then PREVIOUS_FIREWALL_RUNTIME=yes; PREVIOUS_FIREWALL_PERMANENT=yes; fi
    fi
    return 0
}

ensure_firewall_port() {
    if command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then
        FIREWALL_BACKEND=firewalld
        FIREWALL_ZONE="$(firewall-cmd --get-active-zones | awk '$1 != "interfaces:" && $1 != "sources:" { print $1; exit }')"
        [[ -n "$FIREWALL_ZONE" ]] || FIREWALL_ZONE="$(firewall-cmd --get-default-zone)"
        if firewall-cmd --permanent --zone="$FIREWALL_ZONE" --query-port=3000/tcp >/dev/null; then
            firewall-cmd --zone="$FIREWALL_ZONE" --query-port=3000/tcp >/dev/null || firewall-cmd --zone="$FIREWALL_ZONE" --add-port=3000/tcp >/dev/null
            printf '  Firewall: TCP port 3000 already allowed by firewalld (%s zone)\n' "$FIREWALL_ZONE"
        else
            firewall-cmd --permanent --zone="$FIREWALL_ZONE" --add-port=3000/tcp >/dev/null
            firewall-cmd --zone="$FIREWALL_ZONE" --add-port=3000/tcp >/dev/null
            FIREWALL_RULE_ADDED=1
            printf '  Firewall: allowed TCP port 3000 through firewalld (%s zone)\n' "$FIREWALL_ZONE"
        fi
        firewall-cmd --permanent --zone="$FIREWALL_ZONE" --query-port=3000/tcp >/dev/null
        firewall-cmd --zone="$FIREWALL_ZONE" --query-port=3000/tcp >/dev/null
    elif command -v ufw >/dev/null && ufw status | head -n 1 | grep -q '^Status: active'; then
        FIREWALL_BACKEND=ufw
        if ufw status | grep -Eq '^3000/tcp[[:space:]]+ALLOW'; then
            printf '  Firewall: TCP port 3000 already allowed by UFW\n'
        else
            ufw allow 3000/tcp comment 'DVS Mode Switcher' >/dev/null
            FIREWALL_RULE_ADDED=1
            printf '  Firewall: allowed TCP port 3000 through UFW\n'
        fi
        ufw status | grep -Eq '^3000/tcp[[:space:]]+ALLOW'
    else
        printf '  Firewall: no active firewalld or UFW configuration detected; no rule required\n'
    fi
}

CURRENT_ADDRESS="$(ini_get "$LIVE_INI" 'DMR Network' Address)"
CURRENT_NETWORK="$(classify_address "$CURRENT_ADDRESS")"
CURRENT_PASSWORD="$(ini_get "$LIVE_INI" 'DMR Network' Password)"
BM_ADDRESS= BM_PASSWORD= TGIF_PASSWORD=

if [[ "$CURRENT_NETWORK" == bm ]]; then
    BM_ADDRESS="$CURRENT_ADDRESS"
    if credential_usable "$CURRENT_PASSWORD"; then BM_PASSWORD="$CURRENT_PASSWORD"; fi
elif [[ "$CURRENT_NETWORK" == tgif ]]; then
    if credential_usable "$CURRENT_PASSWORD"; then TGIF_PASSWORD="$CURRENT_PASSWORD"; fi
fi

# Upgrades may reuse protected presets. Clean and first installs start from repository defaults.
if [[ "$INSTALL_MODE" == upgrade ]]; then
    if [[ -r "$PRESET_DIR/MMDVM_Bridge.BM.ini" ]]; then
        [[ -n "$BM_ADDRESS" ]] || BM_ADDRESS="$(ini_get "$PRESET_DIR/MMDVM_Bridge.BM.ini" 'DMR Network' Address)"
        candidate="$(ini_get "$PRESET_DIR/MMDVM_Bridge.BM.ini" 'DMR Network' Password)"
        if credential_usable "$candidate"; then BM_PASSWORD="$candidate"; fi
        candidate=
    fi
    if [[ -r "$PRESET_DIR/MMDVM_Bridge.TGIF.ini" ]]; then
        candidate="$(ini_get "$PRESET_DIR/MMDVM_Bridge.TGIF.ini" 'DMR Network' Password)"
        if credential_usable "$candidate"; then TGIF_PASSWORD="$candidate"; fi
        candidate=
    fi
fi

if [[ -z "$BM_PASSWORD" && -r "$DVSWITCH_INI" ]]; then
    candidate="$(ini_get "$DVSWITCH_INI" STFU BMPassword)"
    if credential_usable "$candidate"; then BM_PASSWORD="$candidate"; fi
    candidate=
fi

BASE_INI="$TMP_DIR/base.ini"
cp -a "$LIVE_INI" "$BASE_INI"
CALLSIGN="$(ini_get "$BASE_INI" General Callsign || true)"
if [[ -z "$CALLSIGN" || "$CALLSIGN" == N0CALL ]]; then
    while true; do read -rp 'Amateur-radio callsign: ' CALLSIGN </dev/tty; CALLSIGN="${CALLSIGN^^}"; [[ "$CALLSIGN" =~ ^[A-Z0-9/]{3,12}$ ]] && break; printf 'Enter a valid callsign.\n' >/dev/tty; done
    write_value_file "$TMP_DIR/callsign" "$CALLSIGN"; replace_ini_value "$BASE_INI" General Callsign "$TMP_DIR/callsign" "$TMP_DIR/base.next"; mv "$TMP_DIR/base.next" "$BASE_INI"
fi

DMR_ID="$(ini_get "$BASE_INI" General Id || true)"
if [[ ! "$DMR_ID" =~ ^[0-9]{7}$ || "$DMR_ID" == 1234567 ]]; then
    while true; do read -rp 'Seven-digit DMR/CCS7 ID: ' DMR_ID </dev/tty; [[ "$DMR_ID" =~ ^[0-9]{7}$ && "$DMR_ID" != 1234567 ]] && break; printf 'Enter a valid seven-digit DMR ID.\n' >/dev/tty; done
    write_value_file "$TMP_DIR/dmr-id" "$DMR_ID"; replace_ini_value "$BASE_INI" General Id "$TMP_DIR/dmr-id" "$TMP_DIR/base.next"; mv "$TMP_DIR/base.next" "$BASE_INI"
fi

ANALOG_GATEWAY_ID="$(ini_get_scalar "$ANALOG_INI" AMBE_AUDIO gatewayDmrId || true)"
ANALOG_REPEATER_ID="$(ini_get_scalar "$ANALOG_INI" AMBE_AUDIO repeaterID || true)"
if [[ "$ANALOG_REPEATER_ID" =~ ^[0-9]{9}$ ]]; then
    ANALOG_SSID="${ANALOG_REPEATER_ID:7:2}"
else
    while true; do
        ANALOG_SSID="$(prompt_with_default 'Two-digit Analog_Bridge SSID' 01)"
        [[ "$ANALOG_SSID" =~ ^[0-9]{2}$ ]] && break
        printf 'Enter a two-digit SSID from 00 through 99.\n' >/dev/tty
    done
fi
EXPECTED_REPEATER_ID="${DMR_ID}${ANALOG_SSID}"
ANALOG_UPDATE=0
if [[ "$ANALOG_GATEWAY_ID" != "$DMR_ID" || "$ANALOG_REPEATER_ID" != "$EXPECTED_REPEATER_ID" ]]; then ANALOG_UPDATE=1; fi
ANALOG_OWNER="$(stat -c %U "$ANALOG_INI")"
ANALOG_GROUP="$(stat -c %G "$ANALOG_INI")"
ANALOG_MODE="$(stat -c %a "$ANALOG_INI")"
cp -a "$ANALOG_INI" "$TMP_DIR/Analog_Bridge.ini"
if (( ANALOG_UPDATE )); then
    write_value_file "$TMP_DIR/gateway-dmr-id" "$DMR_ID"
    replace_ini_value "$TMP_DIR/Analog_Bridge.ini" AMBE_AUDIO gatewayDmrId "$TMP_DIR/gateway-dmr-id" "$TMP_DIR/Analog_Bridge.next"
    mv "$TMP_DIR/Analog_Bridge.next" "$TMP_DIR/Analog_Bridge.ini"
    write_value_file "$TMP_DIR/repeater-id" "$EXPECTED_REPEATER_ID"
    replace_ini_value "$TMP_DIR/Analog_Bridge.ini" AMBE_AUDIO repeaterID "$TMP_DIR/repeater-id" "$TMP_DIR/Analog_Bridge.next"
    mv "$TMP_DIR/Analog_Bridge.next" "$TMP_DIR/Analog_Bridge.ini"
fi

NXDN_ID="$(ini_get "$BASE_INI" NXDN Id || true)"
if [[ ! "$NXDN_ID" =~ ^[0-9]{5}$ || "$NXDN_ID" == 12345 ]]; then
    read -rp 'Do you have a five-digit NXDN ID? [y/N]: ' HAVE_NXDN </dev/tty
    if [[ "$HAVE_NXDN" =~ ^[Yy]$ ]]; then
        while true; do read -rp 'Five-digit NXDN ID: ' NXDN_ID </dev/tty; [[ "$NXDN_ID" =~ ^[0-9]{5}$ && "$NXDN_ID" != 12345 ]] && break; printf 'Enter a valid five-digit NXDN ID.\n' >/dev/tty; done
        write_value_file "$TMP_DIR/nxdn-id" "$NXDN_ID"; replace_ini_value "$BASE_INI" NXDN Id "$TMP_DIR/nxdn-id" "$TMP_DIR/base.next"; mv "$TMP_DIR/base.next" "$BASE_INI"
    fi
fi

printf '\nDVSwitch configuration discovery\n'
printf '  Callsign: %s\n' "$CALLSIGN"
printf '  DMR ID: %s\n' "$DMR_ID"
printf '  Analog_Bridge repeater ID: %s (SSID %s)\n' "$EXPECTED_REPEATER_ID" "$ANALOG_SSID"
printf '  NXDN ID: %s\n' "${NXDN_ID:-not configured}"
printf '  Current DMR network: %s\n' "$CURRENT_NETWORK"
printf '  BrandMeister credential: %s\n' "$([[ -n "$BM_PASSWORD" ]] && printf found || printf required)"
printf '  TGIF credential: %s\n' "$([[ -n "$TGIF_PASSWORD" ]] && printf found || printf required)"

BM_ADDRESS="$(prompt_with_default 'BrandMeister master server' "${BM_ADDRESS:-3104.master.brandmeister.network}")"
[[ "$(classify_address "$BM_ADDRESS")" == bm ]] || die "Unrecognized BrandMeister master hostname: $BM_ADDRESS"
if [[ -z "$BM_PASSWORD" ]]; then printf '\nUse the BrandMeister Hotspot Security password, not the website account password.\n'; prompt_secret 'BrandMeister Hotspot Security password'; BM_PASSWORD="$REPLY_SECRET"; REPLY_SECRET=; fi
if [[ -z "$TGIF_PASSWORD" ]]; then printf '\nUse the TGIF secured-connection password, not the website account password.\n'; prompt_secret 'TGIF secured-connection password'; TGIF_PASSWORD="$REPLY_SECRET"; REPLY_SECRET=; fi

DEFAULT_NETWORK="$CURRENT_NETWORK"; [[ "$DEFAULT_NETWORK" == bm || "$DEFAULT_NETWORK" == tgif ]] || DEFAULT_NETWORK=tgif
if [[ "$INSTALL_MODE" == upgrade && -r "$APP_DIR/configs/tg_alias.yml" ]]; then
    EXISTING_FAVORITES_NETWORK="$(prompt_with_default 'Existing DMR favorites belong to (bm or tgif)' "$DEFAULT_NETWORK")"
    EXISTING_FAVORITES_NETWORK="${EXISTING_FAVORITES_NETWORK,,}"
    [[ "$EXISTING_FAVORITES_NETWORK" == bm || "$EXISTING_FAVORITES_NETWORK" == tgif ]] || die "Existing favorites network must be bm or tgif."
    DEFAULT_NETWORK="$EXISTING_FAVORITES_NETWORK"
fi
INITIAL_NETWORK="$(prompt_with_default 'Initial DMR network (bm or tgif)' "$DEFAULT_NETWORK")"; INITIAL_NETWORK="${INITIAL_NETWORK,,}"
[[ "$INITIAL_NETWORK" == bm || "$INITIAL_NETWORK" == tgif ]] || die "Initial network must be bm or tgif."

printf '\nInstallation summary (passwords hidden)\n'
printf '  Install type: %s\n' "$INSTALL_MODE"
[[ -z "$EXISTING_FAVORITES_NETWORK" ]] || printf '  Existing DMR favorites: assigned to %s\n' "$EXISTING_FAVORITES_NETWORK"
printf '  Production directory/port: %s / 3000\n' "$APP_DIR"
printf '  BrandMeister master: %s\n' "$BM_ADDRESS"
printf '  Analog_Bridge IDs: %s\n' "$([[ $ANALOG_UPDATE -eq 1 ]] && printf 'will be synchronized' || printf 'already synchronized')"
printf '  Initial network: %s\n' "$INITIAL_NETWORK"
read -rp 'Continue with installation? [y/N]: ' CONFIRM </dev/tty
[[ "$CONFIRM" =~ ^[Yy]$ ]] || die "Installation cancelled."

log "Generating protected DMR presets from the working live INI"
write_value_file "$TMP_DIR/bm.address" "$BM_ADDRESS"; write_value_file "$TMP_DIR/tgif.address" tgif.network
write_value_file "$TMP_DIR/bm.password" "$BM_PASSWORD"; write_value_file "$TMP_DIR/tgif.password" "$TGIF_PASSWORD"
generate_preset "$BASE_INI" "$TMP_DIR/MMDVM_Bridge.BM.ini" "$TMP_DIR/bm.address" "$TMP_DIR/bm.password"
generate_preset "$BASE_INI" "$TMP_DIR/MMDVM_Bridge.TGIF.ini" "$TMP_DIR/tgif.address" "$TMP_DIR/tgif.password"
[[ "$(ini_get "$TMP_DIR/MMDVM_Bridge.BM.ini" 'DMR Network' Address)" == "$BM_ADDRESS" ]]
[[ "$(ini_get "$TMP_DIR/MMDVM_Bridge.TGIF.ini" 'DMR Network' Address)" == tgif.network ]]
normalized_ini "$TMP_DIR/MMDVM_Bridge.BM.ini" >"$TMP_DIR/bm.normalized"; normalized_ini "$TMP_DIR/MMDVM_Bridge.TGIF.ini" >"$TMP_DIR/tgif.normalized"
cmp -s "$TMP_DIR/bm.normalized" "$TMP_DIR/tgif.normalized" || die "Generated presets differ outside Address and Password."
BM_PASSWORD= TGIF_PASSWORD= CURRENT_PASSWORD=

log "Installing required Debian packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends git nodejs npm ca-certificates curl sudo
NODE_MAJOR="$(node -p 'Number(process.versions.node.split(".")[0])')"; (( NODE_MAJOR >= 18 )) || die "Node.js 18 or newer is required."

log "Preparing the DVS Mode Switcher production application"
STAGE="/opt/.dvswitch-mode-switcher-stage-$STAMP"
if [[ -d "$SCRIPT_DIR/modules" && -f "$SCRIPT_DIR/package.json" && -d "$SCRIPT_DIR/installer" ]]; then
    if [[ -d "$SCRIPT_DIR/.git" ]]; then git clone --no-local "$SCRIPT_DIR" "$STAGE"; else mkdir -p "$STAGE"; cp -a "$SCRIPT_DIR/." "$STAGE/"; fi
else
    git clone --depth 1 "$REPO_URL" "$STAGE"
fi

[[ -f "$STAGE/installer/dvswitch-dmr-network" ]] || die "Repository is missing the DMR helper."
[[ -f "$STAGE/installer/dvswitch_mode_switcher.service" ]] || die "Repository is missing the production service."
[[ -f "$STAGE/installer/dvswitch-mode-switcher.sudoers" ]] || die "Repository is missing the sudo policy."
[[ -f "$STAGE/installer/merge-favorites.js" ]] || die "Repository is missing the favorites migration tool."
[[ -f "$STAGE/installer/restore-backup" ]] || die "Repository is missing the restore tool."
[[ -f "$STAGE/presets/tg_alias.BM.yml" && -f "$STAGE/presets/tg_alias.TGIF.yml" ]] || die "Repository is missing favorites."
(cd "$STAGE" && npm ci --omit=dev)

if [[ "$INSTALL_MODE" == upgrade && -r "$APP_DIR/configs/config.yml" ]]; then
    awk '
        /^[[:space:]]*dmr_network_helper:[[:space:]]*/ { print "dmr_network_helper: /usr/local/sbin/dvswitch-dmr-network-prod"; found=1; next }
        { print }
        END { if (!found) print "dmr_network_helper: /usr/local/sbin/dvswitch-dmr-network-prod" }
    ' "$APP_DIR/configs/config.yml" >"$STAGE/configs/config.yml"
else
    install -m 0644 "$STAGE/configs/config.example.yml" "$STAGE/configs/config.yml"
fi

if [[ "$INSTALL_MODE" == upgrade && -n "$EXISTING_FAVORITES_NETWORK" ]]; then
    log "Preserving existing favorites and assigning DMR to $EXISTING_FAVORITES_NETWORK"
    MERGE_ARGS=(--active "$APP_DIR/configs/tg_alias.yml" --bm "$STAGE/presets/tg_alias.BM.yml" --tgif "$STAGE/presets/tg_alias.TGIF.yml" --network "$EXISTING_FAVORITES_NETWORK")
    [[ ! -r "$PRESET_DIR/tg_alias.BM.yml" ]] || MERGE_ARGS+=(--protected-bm "$PRESET_DIR/tg_alias.BM.yml")
    [[ ! -r "$PRESET_DIR/tg_alias.TGIF.yml" ]] || MERGE_ARGS+=(--protected-tgif "$PRESET_DIR/tg_alias.TGIF.yml")
    node "$STAGE/installer/merge-favorites.js" "${MERGE_ARGS[@]}"
fi

case "$INITIAL_NETWORK" in bm) install -m 0644 "$STAGE/presets/tg_alias.BM.yml" "$STAGE/configs/tg_alias.yml" ;; tgif) install -m 0644 "$STAGE/presets/tg_alias.TGIF.yml" "$STAGE/configs/tg_alias.yml" ;; esac
chown -R root:root "$STAGE"
find "$STAGE" -type d -exec chmod 0755 {} +
find "$STAGE" -type f -exec chmod 0644 {} +
chmod 0755 "$STAGE/install-dvswitch-mode-switcher.sh" "$STAGE/installer/dvswitch-dmr-network" "$STAGE/installer/restore-backup"
chown asl:asl "$STAGE/configs" "$STAGE/configs/config.yml" "$STAGE/configs/tg_alias.yml"
chmod 0755 "$STAGE/configs"; chmod 0644 "$STAGE/configs/config.yml" "$STAGE/configs/tg_alias.yml"

log "Backing up the current production installation"
install -d -o root -g root -m 0700 "$BACKUP_ROOT"
capture_firewall_state
save_or_mark_absent "$APP_DIR" application
save_or_mark_absent "$HELPER" helper; save_or_mark_absent "$UNIT_FILE" unit; save_or_mark_absent "$SUDOERS_FILE" sudoers
cp -a "$LIVE_INI" "$BACKUP_ROOT/live-MMDVM_Bridge.ini"
cp -a "$ANALOG_INI" "$BACKUP_ROOT/live-Analog_Bridge.ini"
[[ ! -f "$APP_DIR/configs/tg_alias.yml" ]] || cp -a "$APP_DIR/configs/tg_alias.yml" "$BACKUP_ROOT/active-tg_alias.yml"
if [[ -d "$PRESET_DIR" ]]; then cp -a "$PRESET_DIR" "$BACKUP_ROOT/presets"; else : >"$BACKUP_ROOT/presets.absent"; fi
PREVIOUS_SERVICE_ACTIVE="$(systemctl is-active "$SERVICE" 2>/dev/null || true)"; [[ -n "$PREVIOUS_SERVICE_ACTIVE" ]] || PREVIOUS_SERVICE_ACTIVE=unknown
PREVIOUS_SERVICE_ENABLED="$(systemctl is-enabled "$SERVICE" 2>/dev/null || true)"; [[ -n "$PREVIOUS_SERVICE_ENABLED" ]] || PREVIOUS_SERVICE_ENABLED=unknown
cat >"$BACKUP_ROOT/manifest" <<EOF
backup_format=1
created=$STAMP
install_mode=$INSTALL_MODE
application=$([[ -e "$BACKUP_ROOT/application" ]] && printf present || printf absent)
service_active=$PREVIOUS_SERVICE_ACTIVE
service_enabled=$PREVIOUS_SERVICE_ENABLED
live_ini=$LIVE_INI
analog_ini=$ANALOG_INI
firewall_backend=$PREVIOUS_FIREWALL_BACKEND
firewall_zone=$PREVIOUS_FIREWALL_ZONE
firewall_runtime_3000=$PREVIOUS_FIREWALL_RUNTIME
firewall_permanent_3000=$PREVIOUS_FIREWALL_PERMANENT
EOF
chmod 0600 "$BACKUP_ROOT/manifest"
BACKUP_COMPLETE=1
systemctl stop "$SERVICE" >/dev/null 2>&1 || true
if [[ -e "$APP_DIR" ]]; then OLD_APP="${APP_DIR}.before-${INSTALL_MODE}-$STAMP"; mv "$APP_DIR" "$OLD_APP"; fi
mv "$STAGE" "$APP_DIR"; STAGE=; SWAPPED=1

log "Installing protected presets and restricted system integration"
if (( ANALOG_UPDATE )); then install -o "$ANALOG_OWNER" -g "$ANALOG_GROUP" -m "$ANALOG_MODE" "$TMP_DIR/Analog_Bridge.ini" "$ANALOG_INI"; fi
install -d -o root -g root -m 0755 "$PRESET_DIR"
install -o root -g root -m 0600 "$TMP_DIR/MMDVM_Bridge.BM.ini" "$PRESET_DIR/MMDVM_Bridge.BM.ini"
install -o root -g root -m 0600 "$TMP_DIR/MMDVM_Bridge.TGIF.ini" "$PRESET_DIR/MMDVM_Bridge.TGIF.ini"
install -o root -g root -m 0644 "$APP_DIR/presets/tg_alias.BM.yml" "$PRESET_DIR/tg_alias.BM.yml"
install -o root -g root -m 0644 "$APP_DIR/presets/tg_alias.TGIF.yml" "$PRESET_DIR/tg_alias.TGIF.yml"
install -o root -g root -m 0755 "$APP_DIR/installer/dvswitch-dmr-network" "$HELPER"
install -o root -g root -m 0644 "$APP_DIR/installer/dvswitch_mode_switcher.service" "$UNIT_FILE"
install -o root -g root -m 0440 "$APP_DIR/installer/dvswitch-mode-switcher.sudoers" "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE" >/dev/null
systemctl daemon-reload; systemctl reset-failed "$SERVICE" >/dev/null 2>&1 || true

log "Activating $INITIAL_NETWORK and matching favorites"
"$HELPER" "$INITIAL_NETWORK"
[[ "$(ini_get_scalar "$ANALOG_INI" AMBE_AUDIO gatewayDmrId)" == "$DMR_ID" ]]
[[ "$(ini_get_scalar "$ANALOG_INI" AMBE_AUDIO repeaterID)" == "$EXPECTED_REPEATER_ID" ]]
[[ "$(stat -c '%U:%G:%a' "$LIVE_INI")" == root:www-data:640 ]]
runuser -u www-data -- test -r "$LIVE_INI"
systemctl enable --now "$SERVICE"; sleep 3

log "Checking firewall access for production TCP port 3000"
ensure_firewall_port

log "Verifying the production installation"
systemctl is-active --quiet "$SERVICE"; systemctl is-active --quiet analog_bridge.service; systemctl is-active --quiet mmdvm_bridge.service
[[ "$(sudo -u asl sudo -n "$HELPER" status)" == "$INITIAL_NETWORK" ]]
cmp -s "$APP_DIR/configs/tg_alias.yml" "$PRESET_DIR/tg_alias.${INITIAL_NETWORK^^}.yml"
curl -fsS --max-time 5 http://127.0.0.1:3000/ >/dev/null
[[ "$(curl -fsS --max-time 5 http://127.0.0.1:3000/dmr-network/status)" == *"\"network\":\"$INITIAL_NETWORK\""* ]]
MAIN_PID="$(systemctl show -p MainPID --value "$SERVICE")"; [[ "$MAIN_PID" =~ ^[1-9][0-9]*$ ]]
sleep 8
[[ "$(systemctl show -p MainPID --value "$SERVICE")" == "$MAIN_PID" ]]
[[ "$(systemctl show -p NRestarts --value "$SERVICE")" == 0 ]]

INSTALL_COMPLETE=1; trap - ERR
IP_ADDR="$(hostname -I 2>/dev/null | awk '{print $1}')"
printf '\nDVS Mode Switcher installation complete.\n'
printf '  Version: %s\n' "$(node -p "require('$APP_DIR/package.json').version")"
printf '  Production: http://%s:3000\n' "${IP_ADDR:-NODE-IP}"
printf '  Service: %s (active, PID %s, zero restarts)\n' "$SERVICE" "$MAIN_PID"
printf '  Active DMR network: %s\n' "$INITIAL_NETWORK"
printf '  Backup: %s\n' "$BACKUP_ROOT"
