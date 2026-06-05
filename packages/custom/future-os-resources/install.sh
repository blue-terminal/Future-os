#!/bin/bash
# Installatore pacchetto risorse Future OS
set -e

RED='\033[0;31m'; CYAN='\033[1;36m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PREFIX="/usr/share/future-os"
THEME_DIR="/usr/share/themes/FutureOS-Dark"
ICON_DIR="/usr/share/icons/FutureOS"
CURSOR_DIR="/usr/share/icons/FutureOS-Cursors"
GRUB_THEME_DIR="/boot/grub/themes/future-os"

echo ""
echo -e "${CYAN}╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌${RESET}"
echo -e "${CYAN}  Future OS Resources - Installazione${RESET}"
echo -e "${CYAN}╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌${RESET}"
echo ""

[ "$(id -u)" -ne 0 ] && { echo -e "${RED}Errore: esegui come root (sudo)${RESET}"; exit 1; }

step() { echo -e "  ${CYAN}→${RESET} $1"; }
ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
warn() { echo -e "  ${YELLOW}!${RESET} $1"; }

step "Creazione directory..."
mkdir -p "$INSTALL_PREFIX"/{wallpapers,sounds,config}
mkdir -p "$THEME_DIR"/gtk-3.0
mkdir -p "$ICON_DIR" "$CURSOR_DIR"
mkdir -p "$GRUB_THEME_DIR"
ok "Directory create"

step "Tema GTK FutureOS-Dark..."
cp "$PKG_DIR/theme/gtk/index.theme" "$THEME_DIR/"
cp "$PKG_DIR/theme/gtk/gtk.css"     "$THEME_DIR/gtk-3.0/gtk.css"
ok "Tema GTK installato"

step "Tema icone FutureOS..."
cp "$PKG_DIR/theme/icons/index.theme" "$ICON_DIR/"
gtk-update-icon-cache -f -t "$ICON_DIR" 2>/dev/null || true
ok "Icone installate"

step "Cursori FutureOS..."
cp "$PKG_DIR/theme/cursors/index.theme" "$CURSOR_DIR/"
ok "Cursori installati"

step "Branding Future OS..."
cp "$PKG_DIR/branding/os-release" /etc/os-release
cp "$PKG_DIR/branding/issue.net"  /etc/issue.net
cp "$PKG_DIR/branding/motd"       /etc/update-motd.d/10-future-os
chmod +x /etc/update-motd.d/10-future-os
rm -f /etc/update-motd.d/10-parrot* 2>/dev/null || true
ok "Branding applicato"

step "Configurazione font..."
cp "$PKG_DIR/fonts/fonts.conf" /etc/fonts/conf.d/99-future-os.conf
fc-cache -f 2>/dev/null || true
ok "Font configurati"

step "Manifest wallpaper e suoni..."
cp "$PKG_DIR/wallpapers/index.json" "$INSTALL_PREFIX/wallpapers/"
cp "$PKG_DIR/sounds/index.json"     "$INSTALL_PREFIX/sounds/"
ok "Manifest installati"

step "Configurazioni desktop..."
cp "$PKG_DIR/config/default-settings.conf" "$INSTALL_PREFIX/config/"
cp "$PKG_DIR/config/desktop.conf"          "$INSTALL_PREFIX/config/"
cp "$PKG_DIR/config/panel.conf"            "$INSTALL_PREFIX/config/"
ok "Configurazioni installate"

step "Tema GRUB..."
cp "$PKG_DIR/grub/theme.txt" "$GRUB_THEME_DIR/"
if [ "${APPLY_GRUB:-0}" = "1" ]; then
    cp "$PKG_DIR/grub/grub-defaults" /etc/default/grub
    update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg
    ok "Tema GRUB applicato"
else
    warn "GRUB non modificato. Usa APPLY_GRUB=1 per applicarlo."
fi

[ -d /etc/lightdm ] && {
    step "LightDM..."
    cp "$PKG_DIR/theme/lightdm/lightdm-gtk-greeter.conf" /etc/lightdm/
    ok "LightDM configurato"
}

echo ""
echo -e "${GREEN}${BOLD}Installazione completata!${RESET}"
echo -e "  Riavvia la sessione per applicare il tema."
echo ""
