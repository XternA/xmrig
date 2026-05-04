#!/bin/sh
set -eu

# ==============================================================================
# NVIDIA Container Toolkit — Automated Setup
# Copyright (c) XternA — https://github.com/XternA/xmrig
# ==============================================================================

NVIDIA_GPG_KEY="/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
NVIDIA_APT_LIST="/etc/apt/sources.list.d/nvidia-container-toolkit.list"
NVIDIA_YUM_REPO="/etc/yum.repos.d/nvidia-container-toolkit.repo"
NVIDIA_REPO_BASE="https://nvidia.github.io/libnvidia-container/stable"
NVIDIA_GPG_URL="https://nvidia.github.io/libnvidia-container/gpgkey"
DAEMON_JSON="/etc/docker/daemon.json"
PACKAGES="nvidia-container-toolkit nvidia-container-toolkit-base libnvidia-container-tools libnvidia-container1"

SUDO=""
PKG_MGR=""
IS_WSL2=false

# --- Output -------------------------------------------------------------------

info()    { printf '  [*] %s\n' "$1"; }
ok()      { printf '  [OK] %s\n' "$1"; }
warn()    { printf '  [!] %s\n' "$1" >&2; }
fail()    { printf '  [ERROR] %s\n' "$1" >&2; exit 1; }

# --- Shared utilities ---------------------------------------------------------

require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "'$1' is required but not installed."; }

detect_root() {
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
    elif command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
        sudo -v 2>/dev/null || fail "Failed to obtain sudo privileges."
    else
        fail "Root privileges required. Run as root or install sudo."
    fi
}

detect_wsl2() {
    IS_WSL2=false
    if [ -f /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
        IS_WSL2=true
    fi
}

detect_os() {
    [ -f /etc/os-release ] || fail "Cannot detect OS — /etc/os-release not found."
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_ID_LIKE="${ID_LIKE:-}"
    OS_NAME="${PRETTY_NAME:-$OS_ID}"
}

detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MGR="zypper"
    else
        fail "No supported package manager found (apt, dnf, zypper)."
    fi
}

restart_docker() {
    info "Restarting Docker..."
    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet docker 2>/dev/null; then
        $SUDO systemctl restart docker
    elif command -v service >/dev/null 2>&1; then
        $SUDO service docker restart
    else
        warn "Could not restart Docker automatically. Please restart it manually."
        return 0
    fi
}

has_nvidia_ctk() { command -v nvidia-ctk >/dev/null 2>&1; }

# --- Detection (install) -----------------------------------------------------

check_docker_desktop() {
    if [ "$IS_WSL2" = true ] && docker info 2>/dev/null | grep -qi "docker desktop"; then
        echo ""
        echo "  Docker Desktop detected on WSL2."
        echo "  GPU support is built in — no toolkit installation needed."
        echo ""
        echo "  Ensure your Windows NVIDIA GPU driver is up to date and the"
        echo "  WSL2 backend is enabled in Docker Desktop settings."
        echo ""
        exit 0
    fi
}

detect_gpu() {
    # WSL2: Microsoft's virtual GPU device
    [ "$IS_WSL2" = true ] && [ -e /dev/dxg ] && return 0
    # Native: PCI bus check
    command -v lspci >/dev/null 2>&1 && lspci 2>/dev/null | grep -qi nvidia && return 0
    # Native: driver loaded
    [ -d /proc/driver/nvidia ] && return 0
    [ -e /dev/nvidia0 ] && return 0

    fail "No NVIDIA GPU detected."
}

validate_platform() {
    _supported=false

    case "$PKG_MGR" in
        apt)
            case "$OS_ID" in ubuntu|debian) _supported=true ;; esac
            [ "$_supported" = false ] && case "$OS_ID_LIKE" in *ubuntu*|*debian*) _supported=true ;; esac
            ;;
        dnf)
            case "$OS_ID" in rhel|centos|rocky|almalinux|fedora|amzn|ol) _supported=true ;; esac
            [ "$_supported" = false ] && case "$OS_ID_LIKE" in *rhel*|*fedora*|*centos*) _supported=true ;; esac
            ;;
        zypper)
            case "$OS_ID" in opensuse*|sles|sled) _supported=true ;; esac
            ;;
    esac

    if [ "$_supported" = false ]; then
        warn "$OS_NAME is not officially supported by NVIDIA."
        warn "Attempting installation anyway via $PKG_MGR..."
    fi
}

# --- Install ------------------------------------------------------------------

install_apt() {
    info "Adding NVIDIA GPG key..."
    curl -fsSL "$NVIDIA_GPG_URL" | $SUDO gpg --dearmor --yes -o "$NVIDIA_GPG_KEY" 2>/dev/null

    info "Adding NVIDIA repository..."
    curl -fsSL "$NVIDIA_REPO_BASE/deb/nvidia-container-toolkit.list" \
        | sed "s#deb https://#deb [signed-by=$NVIDIA_GPG_KEY] https://#g" \
        | $SUDO tee "$NVIDIA_APT_LIST" >/dev/null

    info "Updating package lists..."
    $SUDO apt-get update -qq >/dev/null 2>&1 || warn "apt-get update had warnings (continuing)"

    info "Installing NVIDIA Container Toolkit..."
    $SUDO apt-get install -y -qq nvidia-container-toolkit >/dev/null 2>&1
}

install_dnf() {
    info "Adding NVIDIA repository..."
    curl -fsSL "$NVIDIA_REPO_BASE/rpm/nvidia-container-toolkit.repo" \
        | $SUDO tee "$NVIDIA_YUM_REPO" >/dev/null

    info "Installing NVIDIA Container Toolkit..."
    $SUDO dnf install -y -q nvidia-container-toolkit
}

install_zypper() {
    info "Adding NVIDIA repository..."
    $SUDO zypper --quiet ar "$NVIDIA_REPO_BASE/rpm/nvidia-container-toolkit.repo" \
        nvidia-container-toolkit 2>/dev/null || true

    info "Installing NVIDIA Container Toolkit..."
    $SUDO zypper --gpg-auto-import-keys --quiet install -y nvidia-container-toolkit
}

configure_docker() {
    info "Configuring Docker runtime..."
    $SUDO nvidia-ctk runtime configure --runtime=docker --set-as-default >/dev/null 2>&1
    restart_docker
}

# --- Uninstall ----------------------------------------------------------------

clean_daemon_json() {
    [ -f "$DAEMON_JSON" ] || return 0

    if command -v python3 >/dev/null 2>&1; then
        _cleaned=$(python3 -c "
import json, sys, os

path = sys.argv[1]
try:
    with open(path) as f:
        d = json.load(f)
except (json.JSONDecodeError, FileNotFoundError, PermissionError):
    sys.exit(0)

changed = False
if d.get('default-runtime') == 'nvidia':
    del d['default-runtime']
    changed = True
runtimes = d.get('runtimes', {})
if 'nvidia' in runtimes:
    del runtimes['nvidia']
    changed = True
if not runtimes:
    d.pop('runtimes', None)

if not changed:
    sys.exit(0)
elif not d:
    print('__EMPTY__')
else:
    print(json.dumps(d, indent=4))
" "$DAEMON_JSON" 2>/dev/null) || return 0

        if [ "$_cleaned" = "__EMPTY__" ]; then
            $SUDO rm -f "$DAEMON_JSON"
        elif [ -n "$_cleaned" ]; then
            printf '%s\n' "$_cleaned" | $SUDO tee "$DAEMON_JSON" >/dev/null
        fi

    elif command -v jq >/dev/null 2>&1; then
        _cleaned=$(jq '
            if .["default-runtime"] == "nvidia" then del(.["default-runtime"]) else . end
            | if .runtimes.nvidia then .runtimes |= del(.nvidia) else . end
            | if .runtimes == {} then del(.runtimes) else . end
        ' "$DAEMON_JSON" 2>/dev/null) || return 0

        if [ "$_cleaned" = "{}" ]; then
            $SUDO rm -f "$DAEMON_JSON"
        elif [ -n "$_cleaned" ]; then
            printf '%s\n' "$_cleaned" | $SUDO tee "$DAEMON_JSON" >/dev/null
        fi
    else
        warn "Neither python3 nor jq found."
        warn "Please manually remove NVIDIA entries from $DAEMON_JSON"
    fi
}

remove_packages() {
    # shellcheck disable=SC2086
    case "$PKG_MGR" in
        apt)
            info "Removing packages..."
            $SUDO apt-get remove --purge -y -qq $PACKAGES >/dev/null 2>&1 || true
            $SUDO apt-get autoremove -y -qq >/dev/null 2>&1 || true

            info "Removing NVIDIA repository and GPG key..."
            $SUDO rm -f "$NVIDIA_APT_LIST" "$NVIDIA_GPG_KEY"
            ;;
        dnf)
            info "Removing packages..."
            $SUDO dnf remove -y -q $PACKAGES 2>/dev/null || true

            info "Removing NVIDIA repository..."
            $SUDO rm -f "$NVIDIA_YUM_REPO"
            ;;
        zypper)
            info "Removing packages..."
            $SUDO zypper --quiet remove -y $PACKAGES 2>/dev/null || true

            info "Removing NVIDIA repository..."
            $SUDO zypper removerepo nvidia-container-toolkit 2>/dev/null || true
            ;;
    esac
}

# --- Main flows ---------------------------------------------------------------

do_install() {
    require_cmd curl

    echo ""
    echo "  NVIDIA Container Toolkit — Automated Setup"
    echo "  ==========================================="
    echo ""

    detect_root
    detect_wsl2
    check_docker_desktop

    require_cmd docker
    $SUDO docker info >/dev/null 2>&1 || fail "Docker daemon is not running."

    detect_gpu
    info "NVIDIA GPU detected"

    detect_os
    detect_package_manager
    info "Detected: $OS_NAME ($PKG_MGR)"
    validate_platform

    if has_nvidia_ctk; then
        info "Already installed. Reconfiguring Docker runtime..."
        configure_docker
        echo ""
        ok "Docker reconfigured with NVIDIA runtime."
        echo ""
        return 0
    fi

    case "$PKG_MGR" in
        apt)    install_apt ;;
        dnf)    install_dnf ;;
        zypper) install_zypper ;;
    esac
    ok "NVIDIA Container Toolkit installed"

    configure_docker

    echo ""
    ok "Setup complete. GPU containers are now enabled."
    echo ""
}

do_uninstall() {
    echo ""
    echo "  NVIDIA Container Toolkit — Uninstall"
    echo "  ====================================="
    echo ""

    detect_root

    if ! has_nvidia_ctk; then
        info "NVIDIA Container Toolkit is not installed. Nothing to do."
        echo ""
        return 0
    fi

    detect_package_manager

    info "Removing NVIDIA runtime from Docker config..."
    clean_daemon_json
    restart_docker

    remove_packages

    echo ""
    ok "NVIDIA Container Toolkit has been fully removed."
    echo ""
}


# --- Entry point --------------------------------------------------------------

case "${1:-}" in
    --uninstall) do_uninstall ;;
    *)           do_install ;;
esac
