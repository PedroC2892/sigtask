#!/usr/bin/env bash
# Install or remove sigtask for the current user.
# Usage: ./install.sh [--uninstall]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
MARKER="sigtask: send signal submenu"

KDE_PLASMOID=plasma/plasmoids/org.kde.plasma.taskmanager
KDE_USER="$DATA/$KDE_PLASMOID"
GNOME_UUID=sigtask@pedroafonsocruz.github.io
GNOME_USER="$DATA/gnome-shell/extensions/$GNOME_UUID"

desktop="${XDG_CURRENT_DESKTOP:-}"
staging=""

# The system copy can live under any XDG data dir (/usr/share, /usr/local/share, NixOS store, ...).
find_kde_system() {
    local dir
    IFS=: read -ra dirs <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    for dir in "${dirs[@]}"; do
        [[ -n "$dir" && -f "$dir/$KDE_PLASMOID/contents/ui/ContextMenu.qml" ]] && { echo "$dir/$KDE_PLASMOID"; return; }
    done
    return 1
}

is_ours() {
    grep -qF "$MARKER" "$KDE_USER/contents/ui/ContextMenu.qml" 2>/dev/null
}

restart_plasmashell() {
    systemctl --user restart plasma-plasmashell.service 2>/dev/null && return
    if command -v kquitapp6 >/dev/null; then
        kquitapp6 plasmashell >/dev/null 2>&1 || true
        (kstart plasmashell >/dev/null 2>&1 &)
        return
    fi
    echo "Restart plasmashell to apply (log out and back in)."
}

install_kde() {
    local system
    system="$(find_kde_system)" || { echo "Plasma task manager not found in XDG_DATA_DIRS" >&2; exit 1; }
    if [[ -e "$KDE_USER" ]] && ! is_ours; then
        echo "$KDE_USER exists and was not created by sigtask; refusing to overwrite it." >&2
        exit 1
    fi
    # Patch in a staging dir so a failed patch never leaves a broken override in place.
    mkdir -p "$(dirname "$KDE_USER")"
    staging="$(mktemp -d "$(dirname "$KDE_USER")/.sigtask.XXXXXX")"
    trap '[[ -n "$staging" ]] && rm -rf "$staging"' EXIT
    cp -r "$system/." "$staging"
    python3 "$REPO/kde/patch_contextmenu.py" "$staging/contents/ui/ContextMenu.qml"
    rm -rf "$KDE_USER"
    mv "$staging" "$KDE_USER"
    restart_plasmashell
    echo "Installed for KDE Plasma (from $system)."
}

install_gnome() {
    rm -rf "$GNOME_USER"
    mkdir -p "$(dirname "$GNOME_USER")"
    cp -r "$REPO/gnome/$GNOME_UUID" "$GNOME_USER"
    gnome-extensions enable "$GNOME_UUID" 2>/dev/null \
        || echo "Log out and back in, then run: gnome-extensions enable $GNOME_UUID"
    echo "Installed for GNOME."
}

uninstall() {
    if is_ours; then
        rm -rf "$KDE_USER"
        restart_plasmashell
        echo "Removed KDE Plasma patch."
    fi
    if [[ -d "$GNOME_USER" ]]; then
        gnome-extensions disable "$GNOME_UUID" 2>/dev/null || true
        rm -rf "$GNOME_USER"
        echo "Removed GNOME extension."
    fi
}

if [[ "${1:-}" == "--uninstall" ]]; then
    uninstall
    exit 0
fi

# XDG_CURRENT_DESKTOP is a colon-separated list, e.g. "ubuntu:GNOME".
case ":$desktop:" in
    *:KDE:*) install_kde ;;
    *:GNOME:*) install_gnome ;;
    *) echo "Unsupported desktop: '${desktop:-unknown}'. Supported: KDE Plasma 6, GNOME 45+." >&2; exit 1 ;;
esac
