#!/bin/bash
# Rimozione future-os-updater
set -e

CYAN='\033[1;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
RESET='\033[0m'; BOLD='\033[1m'

[ "$(id -u)" -ne 0 ] && { echo -e "${RED}Errore: esegui come root${RESET}"; exit 1; }

step() { echo -e "  ${CYAN}→${RESET} $1"; }
ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }

echo -e "\n${CYAN}Rimozione Future OS Updater...${RESET}\n"

step "Disattivazione timer..."
systemctl disable --now future-os-updater.timer 2>/dev/null || true
systemctl disable --now future-os-updater.service 2>/dev/null || true
ok "Timer disattivato"

step "Rimozione file systemd..."
rm -f /etc/systemd/system/future-os-updater.{service,timer}
systemctl daemon-reload
ok "Rimossi"

step "Rimozione script..."
rm -f /usr/local/bin/future-os-update
ok "Rimosso"

step "Rimozione configurazione APT..."
rm -f /etc/apt/apt.conf.d/20auto-upgrades
rm -f /etc/apt/apt.conf.d/50unattended-upgrades
ok "Rimossa"

echo -e "\n${GREEN}${BOLD}Rimozione completata.${RESET}\n"
