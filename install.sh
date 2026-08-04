#!/bin/bash
#
# yakushidotfilesv2 installer
# Tek komutla calistirin:  ./install.sh
#
# Bu betik:
#   1) Gereken tum paketleri (Hyprland 0.55+ lua-config ekosistemi dahil) kurar
#   2) Nerd Font'u kurar ve font onbellegini yeniler (fastfetch/waybar/rofi
#      ikonlarinin/ascii art'inin bozuk gorunmesinin ana sebebi buydu)
#   3) Dotfiles'i ~/.config altina symlink'ler, mevcut config'leri SILMEK
#      yerine yedekler
#
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config/yakushidotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# ---------------------------------------------------------------------------
# 0) Ortam kontrolleri
# ---------------------------------------------------------------------------
if ! command -v pacman &>/dev/null; then
    echo "HATA: Bu betik yalnizca pacman kullanan Arch (tabanli) sistemlerde calisir." >&2
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    echo "HATA: Bu betigi root olarak degil, normal kullanici olarak calistirin." >&2
    echo "      (sudo gerektiginde zaten sifre soracak)" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 1) Paket listeleri
# ---------------------------------------------------------------------------

# Dotfiles icindeki binding/script'lerin DOGRUDAN ihtiyac duydugu paketler
CORE_PACKAGES=(
    hyprland        # compositor - 0.55+ ile lua config destegi resmi repoda
    waybar          # durum cubugu
    rofi            # launcher / powermenu / pano gecmisi menusu
    kitty           # terminal
    fastfetch       # sistem bilgisi (bashrc'de her terminalde calisiyor)
    cava            # waybar'daki custom/cava ses gorsellestirici modulu
    nautilus        # $fileManager (SUPER+E)
    hyprshot        # SUPER+SHIFT+S ekran goruntusu
    hyprlauncher    # $menu (SUPER+R)
    hyprlock        # powermenu.sh -> kilit ekrani secenegi
    awww            # exec-once = awww-daemon (duvar kagidi daemon'i)
    hyprsunset      # exec-once = hyprsunset (mavi isik filtresi)
    playerctl       # medya tuslari (play/pause/next/prev)
    brightnessctl   # parlaklik tuslari
    wl-clipboard    # cliphist-rofi-img.sh icinde wl-copy
    cliphist        # pano gecmisi
    gawk            # cliphist-rofi-img.sh icindeki awk script'i
    git
    curl
)

# Nerd Font: kitty, rofi, waybar (Propo varyanti dahil) ve fastfetch'in
# ikon/glyph gerektiren TUM ayarlari bu TEK pakete bagli. Kurulu degilse
# ikonlar/ascii art bos kutu (tofu) olarak gorunur - asil "sorunlu" gorunumun
# sebebi buydu.
FONT_PACKAGES=(
    ttf-jetbrains-mono-nerd
)

# Dotfiles'ta dogrudan referans edilmez ama bunlar olmadan tam bir Hyprland
# masaustunde GUI sifre/izin istemleri (polkit) ve ekran paylasimi/portal
# istekleri sessizce basarisiz olur. Istenmezse asagidaki satiri silebilirsiniz.
RECOMMENDED_PACKAGES=(
    hyprpolkitagent          # GUI polkit izin/sifre istemleri
    xdg-desktop-portal-hyprland  # ekran paylasimi, dosya secici portali
)

ALL_PACKAGES=(
    "${CORE_PACKAGES[@]}"
    "${FONT_PACKAGES[@]}"
    "${RECOMMENDED_PACKAGES[@]}"
)

# Not: pactl komutlari (ses tuslari) PipeWire+pipewire-pulse ya da PulseAudio
# gerektirir. Bu genelde temel Arch kurulumunda zaten ayarlandigi icin
# buraya dahil edilmedi; yoksa 'sudo pacman -S pipewire pipewire-pulse
# wireplumber' ile kurabilirsiniz.

# ---------------------------------------------------------------------------
# 2) Paketleri kur
# ---------------------------------------------------------------------------
echo ":: Sistem senkronize ediliyor ve ${#ALL_PACKAGES[@]} paket kuruluyor..."
# -Syu (sadece -S degil) kullaniyoruz: Arch'ta "partial upgrade" (senkronize
# etmeden yeni paket kurmak) bagimlilik sorunlarina yol acabilir.
sudo pacman -Syu --needed --noconfirm "${ALL_PACKAGES[@]}"

echo ":: Font onbellegi yenileniyor..."
fc-cache -f >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# 3) Dotfiles'i baglama (mevcut config'leri silmek yerine yedekler)
# ---------------------------------------------------------------------------
echo ":: Dotfiles baglaniyor..."
mkdir -p "$HOME/.config"

SKIP_LIST=("install.sh" "README.md" ".git" ".gitignore" ".bashrc")

should_skip() {
    local name="$1"
    for s in "${SKIP_LIST[@]}"; do
        [ "$name" = "$s" ] && return 0
    done
    return 1
}

# src -> dest symlink'i guvenli sekilde kurar: zaten dogru link ise dokunmaz,
# gercek bir dosya/klasor varsa SILMEK yerine BACKUP_DIR'a tasir.
link_target() {
    local src="$1" dest="$2"

    if [ -L "$dest" ] && [ "$(readlink -f "$dest" 2>/dev/null)" = "$(readlink -f "$src")" ]; then
        echo "   -> $(basename "$dest") zaten guncel, atlaniyor"
        return 0
    fi

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        mkdir -p "$BACKUP_DIR"
        echo "   -> Mevcut $(basename "$dest") yedekleniyor -> $BACKUP_DIR/"
        mv "$dest" "$BACKUP_DIR/"
    fi

    ln -s "$src" "$dest"
    echo "   -> $(basename "$dest") baglandi"
}

for config in "$DOTFILES_DIR"/*; do
    config_name=$(basename "$config")
    should_skip "$config_name" && continue
    link_target "$config" "$HOME/.config/$config_name"
done

# .bashrc, .config disinda oldugu icin ayri isleniyor
link_target "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"

echo ""
echo ":: Kurulum tamamlandi."
if [ -d "$BACKUP_DIR" ]; then
    echo "   Eski config'leriniz yedeklendi: $BACKUP_DIR"
fi
echo "   Hyprland'i baslatmak icin: Hyprland  (ya da TTY/display manager'dan secin)"
echo "   -Syu bir kernel/surucu guncellemesi getirdiyse yeniden baslatmaniz onerilir."
