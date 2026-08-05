#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.local/share/yakushidotfiles/backups/$(date +%Y%m%d-%H%M%S)"

if ! command -v pacman &>/dev/null; then
    echo "ERROR: This installer only supports Arch Linux and Arch-based distributions."
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Please run this installer as a regular user."
    echo "sudo will be used automatically when required."
    exit 1
fi

echo "This installer will:"
echo "  • Install the required packages"
echo "  • Replace existing configuration files with symlinks"
echo "  • Back up your current configuration files to:"
echo "    $BACKUP_DIR"
echo

read -rp "Continue? [Y/n] " reply
case "$reply" in
    ""|[Yy]|[Yy][Ee][Ss]) ;;
    *) echo "Installation cancelled."; exit 0 ;;
esac

CORE_PACKAGES=(
    hyprland
    waybar
    rofi
    kitty
    fastfetch
    nautilus
    hyprshot
    hyprlock
    swww
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
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
    xdg-utils
    xdg-user-dirs
)

ALL_PACKAGES=(
    "${CORE_PACKAGES[@]}"
    "${FONT_PACKAGES[@]}"
    "${RECOMMENDED_PACKAGES[@]}"
)

echo ":: Installing ${#ALL_PACKAGES[@]} packages..."
sudo pacman -Syu --needed --noconfirm "${ALL_PACKAGES[@]}"

echo ":: Refreshing font cache..."
fc-cache -f

echo ":: Linking dotfiles..."
mkdir -p "$HOME/.config"

SKIP_LIST=(
    install.sh
    README.md
    .git
    .gitignore
    .bashrc
)

should_skip() {
    local name="$1"
    for item in "${SKIP_LIST[@]}"; do
        [[ "$name" == "$item" ]] && return 0
    done
    return 1
}

link_target() {
    local src="$1"
    local dest="$2"

    if [[ -L "$dest" ]] && [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        echo "   • $(basename "$dest") is already linked."
        return
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
        mkdir -p "$BACKUP_DIR"
        echo "   • Backing up $(basename "$dest")..."
        mv "$dest" "$BACKUP_DIR/"
    fi

    ln -s "$src" "$dest"
    echo "   • Linked $(basename "$dest")."
}

for config in "$DOTFILES_DIR"/*; do
    config_name="${config##*/}"
    should_skip "$config_name" && continue
    link_target "$config" "$HOME/.config/$config_name"
done

link_target "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"

echo
echo ":: Installation completed successfully."

if [[ -d "$BACKUP_DIR" ]]; then
    echo "Backup location:"
    echo "  $BACKUP_DIR"
fi

echo
echo "You can now start Hyprland by selecting it from your display manager"
echo "or by running:"
echo
echo "  Hyprland"
echo
echo "If the update installed a new kernel or graphics driver,"
echo "it is recommended to reboot your system."
