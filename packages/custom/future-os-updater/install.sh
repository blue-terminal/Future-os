#!/bin/bash
# Installatore future-os-updater
set -e

CYAN='\033[1;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ "$(id -u)" -ne 0 ] && { echo -e "${RED}Errore: esegui come root (sudo)${RESET}"; exit 1; }

step() { echo -e "  ${CYAN}→${RESET} $1"; }
ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }

echo -e "\n${CYAN}╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌${RESET}"
echo -e "${CYAN}  Future OS Updater - Installazione${RESET}"
echo -e "${CYAN}╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌${RESET}\n"

step "Dipendenze..."
apt-get install -y -q unattended-upgrades apt-listchanges libnotify-bin
ok "Dipendenze installate"

step "Comando 'smart'..."
install -m 755 "$PKG_DIR/smart.sh" /usr/local/bin/smart
ok "Installato: /usr/local/bin/smart"

step "Script updater interno..."
install -m 755 "$PKG_DIR/future-os-update.sh" /usr/local/bin/future-os-update
ok "Installato: /usr/local/bin/future-os-update"

step "Configurazione APT auto-upgrades..."
install -m 644 "$PKG_DIR/apt/20auto-upgrades"                  /etc/apt/apt.conf.d/20auto-upgrades
install -m 644 "$PKG_DIR/apt/50unattended-upgrades-future-os" /etc/apt/apt.conf.d/50unattended-upgrades
ok "APT configurato"

step "Servizio systemd..."
install -m 644 "$PKG_DIR/systemd/future-os-updater.service" /etc/systemd/system/
install -m 644 "$PKG_DIR/systemd/future-os-updater.timer"   /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now future-os-updater.timer
ok "Timer attivato (aggiornamento automatico giornaliero alle 03:00)"

step "Directory log..."
mkdir -p /var/log/future-os /var/lib/future-os
ok "Pronto"

echo -e "\n${GREEN}${BOLD}Installazione completata!${RESET}"
echo -e "  Per aggiornare il sistema esegui:"
echo -e "    ${BOLD}sudo smart update${RESET}"
echo -e "  Per vedere lo stato:"
echo -e "    ${BOLD}smart status${RESET}"
echo -e "  Per il log:"
echo -e "    ${BOLD}smart log${RESET}\n"
