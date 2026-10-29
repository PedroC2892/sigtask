#!/usr/bin/env bash
# Install or remove sigtask for the current user.
# Usage: ./install.sh [--uninstall]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"

KDE_SYSTEM=/usr/share/plasma/plasmoids/org.kde.plasma.taskmanager
KDE_USER="$DATA/plasma/plasmoids/org.kde.plasma.taskmanager"
GNOME_UUID=sigtask@pedroafonsocruz.github.io
GNOME_USER="$DATA/gnome-shell/extensions/$GNOME_UUID"

desktop="${XDG_CURRENT_DESKTOP:-}"

install_kde() {
    [[ -d "$KDE_SYSTEM" ]] || { echo "Plasma task manager not found at $KDE_SYSTEM" >&2; exit 1; }
    # Always start from the system copy so Plasma upgrades are picked up on reinstall.
    rm -rf "$KDE_USER"
    mkdir -p "$(dirname "$KDE_USER")"
    cp -r "$KDE_SYSTEM" "$KDE_USER"
    python3 "$REPO/kde/patch_contextmenu.py" "$KDE_USER/contents/ui/ContextMenu.qml"
    systemctl --user restart plasma-plasmashell.service 2>/dev/null \
        || echo "Restart plasmashell to apply (log out and back in)."
    echo "Installed for KDE Plasma."
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
    if [[ -d "$KDE_USER" ]] && grep -q "sigtask" "$KDE_USER/contents/ui/ContextMenu.qml" 2>/dev/null; then
        rm -rf "$KDE_USER"
        systemctl --user restart plasma-plasmashell.service 2>/dev/null || true
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

case "$desktop" in
    *KDE*) install_kde ;;
    *GNOME*|*ubuntu*|*Unity*) install_gnome ;;
    *) echo "Unsupported desktop: '${desktop:-unknown}'. Supported: KDE Plasma 6, GNOME 45+." >&2; exit 1 ;;
esac
