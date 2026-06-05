#!/bin/bash
# /usr/local/bin/smart - CLI principale Future OS
# Utilizzo: sudo smart <comando>

CYAN='\033[1;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'

VERSION="1.0.0"
LOG=/var/log/future-os/updater.log
STAMP=/var/lib/future-os/last-update

usage() {
    echo -e ""
    echo -e "  ${CYAN}${BOLD}smart${RESET} - Gestore sistema Future OS v${VERSION}"
    echo -e ""
    echo -e "  ${BOLD}Utilizzo:${RESET}"
    echo -e "    sudo smart update          Aggiorna il sistema"
    echo -e "    sudo smart update --full   Aggiorna tutti i pacchetti"
    echo -e "         smart status          Stato aggiornamenti"
    echo -e "         smart log             Mostra log aggiornamenti"
    echo -e "         smart log --tail N    Ultime N righe di log"
    echo -e "         smart help            Mostra questo aiuto"
    echo -e ""
}

cmd_update() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Errore: 'smart update' richiede i permessi di root.${RESET}"
        echo -e "  Usa: ${BOLD}sudo smart update${RESET}"
        exit 1
    fi

    local full=0
    [ "${1:-}" = "--full" ] && full=1

    echo -e ""
    echo -e "${CYAN}╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌${RESET}"
    echo -e "${CYAN}  Future OS - Aggiornamento sistema${RESET}"
    echo -e "${CYAN}╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌${RESET}"
    echo -e ""

    echo -e "  ${CYAN}→${RESET} Aggiornamento lista pacchetti..."
    apt-get update -q 2>&1 | grep -E '(Scaric|Get|Hit|Ign|Err)' | sed 's/^/    /' || true
    echo -e "  ${GREEN}✓${RESET} Lista aggiornata"

    UPDATES=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst' || true)
    SEC=$(apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep -c 'security' || true)
    FOS=$(apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep -c 'future-os' || true)

    if [ "$UPDATES" -eq 0 ]; then
        echo -e "  ${GREEN}✓${RESET} Il sistema è già aggiornato."
        echo ""
        exit 0
    fi

    echo -e "  ${YELLOW}•${RESET} Trovati ${BOLD}${UPDATES}${RESET} aggiornamenti  (${SEC} sicurezza, ${FOS} Future OS)"
    echo ""

    if [ "$full" -eq 1 ]; then
        echo -e "  ${CYAN}→${RESET} Installazione aggiornamenti completi..."
        AUTO_UPGRADE=1 /usr/local/bin/future-os-update
    else
        echo -e "  ${CYAN}→${RESET} Installazione aggiornamenti sicurezza + Future OS..."
        /usr/local/bin/future-os-update
    fi

    echo ""
    if [ -f /var/run/reboot-required ]; then
        echo -e "  ${YELLOW}!${RESET} Riavvio consigliato per completare l'aggiornamento."
    else
        echo -e "  ${GREEN}✓${RESET} Aggiornamento completato."
    fi
    echo ""
}

cmd_status() {
    echo -e ""
    echo -e "  ${CYAN}${BOLD}Stato aggiornamenti Future OS${RESET}"
    echo ""

    apt-get update -q &>/dev/null || true
    UPDATES=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst' || true)
    SEC=$(apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep -c 'security' || true)
    FOS=$(apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep -c 'future-os' || true)

    if [ "$UPDATES" -eq 0 ]; then
        echo -e "  ${GREEN}✓${RESET} Sistema aggiornato"
    else
        echo -e "  ${YELLOW}•${RESET} ${BOLD}${UPDATES}${RESET} aggiornamenti disponibili"
        echo -e "    - ${SEC} di sicurezza"
        echo -e "    - ${FOS} Future OS"
        echo -e "  Esegui: ${BOLD}sudo smart update${RESET}"
    fi

    echo ""
    if [ -f "$STAMP" ]; then
        echo -e "  Ultimo aggiornamento: $(cat "$STAMP")"
    else
        echo -e "  Nessun aggiornamento eseguito ancora."
    fi

    if systemctl is-active --quiet future-os-updater.timer 2>/dev/null; then
        NEXT=$(systemctl status future-os-updater.timer 2>/dev/null | grep 'Trigger:' | sed 's/.*Trigger: //' | xargs)
        echo -e "  Prossimo automatico: ${NEXT:-non disponibile}"
    else
        echo -e "  ${YELLOW}!${RESET} Timer automatico non attivo. Installa future-os-updater per abilitarlo."
    fi
    echo ""
}

cmd_log() {
    local lines=50
    [ "${1:-}" = "--tail" ] && lines="${2:-50}"

    if [ ! -f "$LOG" ]; then
        echo -e "${YELLOW}Nessun log disponibile ancora.${RESET}"
        exit 0
    fi

    echo -e "\n  ${CYAN}${BOLD}Log aggiornamenti Future OS${RESET} (ultime ${lines} righe)\n"
    tail -n "$lines" "$LOG" | sed 's/^/  /'
    echo ""
}

case "${1:-help}" in
    update) shift; cmd_update "$@" ;;
    status) cmd_status ;;
    log)    shift; cmd_log "$@" ;;
    help|-h|--help) usage ;;
    *)
        echo -e "${RED}Comando sconosciuto: '${1}'${RESET}"
        usage
        exit 1
        ;;
esac
