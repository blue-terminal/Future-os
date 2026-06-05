#!/bin/bash
# Rimozione pacchetto risorse Future OS
set -e

CYAN='\033[1;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
RESET='\033[0m'; BOLD='\033[1m'

[ "$(id -u)" -ne 0 ] && { echo -e "${RED}Errore: esegui come root${RESET}"; exit 1; }

step() { echo -e "  ${CYAN}→${RESET} $1"; }
ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }

echo -e "\n${CYAN}Rimozione risorse Future OS...${RESET}\n"

step "Tema GTK...";          rm -rf /usr/share/themes/FutureOS-Dark;  ok "Rimosso"
step "Icone e cursori...";   rm -rf /usr/share/icons/FutureOS{,-Cursors}; ok "Rimossi"
step "Font config...";       rm -f  /etc/fonts/conf.d/99-future-os.conf; fc-cache -f 2>/dev/null || true; ok "Rimossa"
step "MOTD...";              rm -f  /etc/update-motd.d/10-future-os; ok "Rimosso"
step "Risorse sistema...";   rm -rf /usr/share/future-os;            ok "Rimosse"
step "Tema GRUB...";         rm -rf /boot/grub/themes/future-os;     ok "Rimosso"

echo -e "\n${GREEN}${BOLD}Rimozione completata.${RESET}\n"
