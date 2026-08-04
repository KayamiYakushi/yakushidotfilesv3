#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config/yakushidotfiles-backup-$(date +%Y%m%d-%H%M%S)"

if ! command -v pacman &>/dev/null; then
    echo "HATA: Bu betik yalnizca pacman kullanan Arch (tabanli) sistemlerde calisir." >&2
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    echo "HATA: Bu betigi root olarak degil, normal kullanici olarak calistirin." >&2
    echo "      (sudo gerektiginde zaten sifre soracak)" >&2
    exit 1
fi

CORE_PACKAGES=(
    hyprland
    waybar
    rofi
    kitty
    fastfetch
    nautilus
    hyprshot
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

FONT_PACKAGES=(
    ttf-jetbrains-mono-nerd
)

RECOMMENDED_PACKAGES=(
    hyprpolkitagent
    xdg-desktop-portal-hyprland
)

ALL_PACKAGES=(
    "${CORE_PACKAGES[@]}"
    "${FONT_PACKAGES[@]}"
    "${RECOMMENDED_PACKAGES[@]}"
)


echo ":: Synchronizing system ${#ALL_PACKAGES[@]} installing packages..."
sudo pacman -Syu --needed --noconfirm "${ALL_PACKAGES[@]}"

echo ":: Font onbellegi yenileniyor..."
fc-cache -f >/dev/null 2>&1 || true

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


link_target() {
    local src="$1" dest="$2"

    if [ -L "$dest" ] && [ "$(readlink -f "$dest" 2>/dev/null)" = "$(readlink -f "$src")" ]; then
        echo "   -> $(basename "$dest") Up to date, skipping..."
        return 0
    fi

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        mkdir -p "$BACKUP_DIR"
        echo "   -> Mevcut $(basename "$dest") Backing up... -> $BACKUP_DIR/"
        mv "$dest" "$BACKUP_DIR/"
    fi

    ln -s "$src" "$dest"
    echo "   -> $(basename "$dest") Linked."
}

for config in "$DOTFILES_DIR"/*; do
    config_name=$(basename "$config")
    should_skip "$config_name" && continue
    link_target "$config" "$HOME/.config/$config_name"
done

link_target "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"

echo ""
echo ":: Installation completed."
if [ -d "$BACKUP_DIR" ]; then
    echo "   Your old configurations have been backed up.: $BACKUP_DIR"
fi
echo "   To start Hyprland: Hyprland (or select it from TTY/display manager)"
echo "   -Syu is recommended to restart if it has brought a kernel/driver update."
