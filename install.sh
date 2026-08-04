#!/bin/bash

# yakushidotfilesv3 installer
# Run: ./install.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config/yakushidotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# -----------------------------------------------------------------------------
# Environment checks
# -----------------------------------------------------------------------------

if ! command -v pacman &>/dev/null; then
    echo "HATA: Bu betik yalnizca pacman kullanan Arch (tabanli) sistemlerde calisir." >&2
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    echo "HATA: Bu betigi root olarak degil, normal kullanici olarak calistirin." >&2
    echo "      (sudo gerektiginde zaten sifre soracak)" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Package lists
# -----------------------------------------------------------------------------

# Required packages
CORE_PACKAGES=(
    hyprland
    waybar
    rofi
    kitty
    fastfetch
    cava
    nautilus
    hyprshot
    hyprlauncher
    hyprlock
    awww
    hyprsunset
    playerctl
    brightnessctl
    wl-clipboard
    cliphist
    gawk
    git
    curl
)

# Required Nerd Font
FONT_PACKAGES=(
    ttf-jetbrains-mono-nerd
)

# Recommended desktop packages
RECOMMENDED_PACKAGES=(
    hyprpolkitagent
    xdg-desktop-portal-hyprland
)

ALL_PACKAGES=(
    "${CORE_PACKAGES[@]}"
    "${FONT_PACKAGES[@]}"
    "${RECOMMENDED_PACKAGES[@]}"
)

# PipeWire/PulseAudio packages are not included.

# -----------------------------------------------------------------------------
# Install packages
# -----------------------------------------------------------------------------

echo ":: Synchronizing system and installing ${#ALL_PACKAGES[@]} packages..."

# Full system upgrade before install
sudo pacman -Syu --needed --noconfirm "${ALL_PACKAGES[@]}"

echo ":: Refreshing font cache..."
fc-cache -f >/dev/null 2>&1 || true

# -----------------------------------------------------------------------------
# Link dotfiles
# -----------------------------------------------------------------------------

echo ":: Linking dotfiles..."
mkdir -p "$HOME/.config"

SKIP_LIST=("install.sh" "README.md" ".git" ".gitignore" ".bashrc")

should_skip() {
    local name="$1"

    for s in "${SKIP_LIST[@]}"; do
        [ "$name" = "$s" ] && return 0
    done

    return 1
}

# Create symlink safely
link_target() {
    local src="$1"
    local dest="$2"

    # Skip if already linked
    if [ -L "$dest" ] && [ "$(readlink -f "$dest" 2>/dev/null)" = "$(readlink -f "$src")" ]; then
        echo "   -> $(basename "$dest") already linked"
        return 0
    fi

    # Backup existing file
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        mkdir -p "$BACKUP_DIR"
        echo "   -> Backing up $(basename "$dest")"
        mv "$dest" "$BACKUP_DIR/"
    fi

    ln -s "$src" "$dest"
    echo "   -> Linked $(basename "$dest")"
}

for config in "$DOTFILES_DIR"/*; do
    config_name=$(basename "$config")

    should_skip "$config_name" && continue

    link_target "$config" "$HOME/.config/$config_name"
done

# Link .bashrc separately
link_target "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"

echo ""
echo ":: Installation complete."

if [ -d "$BACKUP_DIR" ]; then
    echo "   Backup saved to: $BACKUP_DIR"
fi

echo "   Start Hyprland with: Hyprland"
echo "   Reboot if the system or kernel was updated."
