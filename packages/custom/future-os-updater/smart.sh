#!/bin/bash
# /usr/local/bin/smart - CLI principale Future OS

CYAN='\033[1;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'

VERSION="1.0.0"
LOG=/var/log/future-os/updater.log
STAMP=/var/lib/future-os/last-update
REPO_DIR=/opt/future-os

usage() {
    echo -e ""
    echo -e "  ${CYAN}${BOLD}smart${RESET} - Gestore sistema Future OS v${VERSION}"
    echo -e ""
    echo -e "  ${BOLD}Utilizzo:${RESET}"
    echo -e "    sudo smart update          Aggiorna repo + sicurezza + pacchetti Future OS"
    echo -e "    sudo smart update --full   Aggiorna tutto (inclusi pacchetti di sistema)"
    echo -e "         smart status          Stato aggiornamenti"
    echo -e "         smart log             Log aggiornamenti"
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

    # 1. Repo
    echo -e "  ${CYAN}→${RESET} Sincronizzazione repository..."
    if [ -d "$REPO_DIR/.git" ]; then
        BEFORE=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || echo "?")
        git -C "$REPO_DIR" fetch origin main -q 2>/dev/null && \
        git -C "$REPO_DIR" reset --hard origin/main -q 2>/dev/null || true
        AFTER=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || echo "?")
        if [ "$BEFORE" != "$AFTER" ] && [ "$BEFORE" != "?" ]; then
            echo -e "  ${GREEN}✓${RESET} Repository aggiornato"
            NFILES=$(git -C "$REPO_DIR" diff --name-only "$BEFORE" "$AFTER" 2>/dev/null | wc -l)
            echo -e "    ${NFILES} file modificati"
        else
            echo -e "  ${GREEN}✓${RESET} Repository già aggiornato"
        fi
    else
        echo -e "  ${YELLOW}!${RESET} Repository non trovato in $REPO_DIR"
        echo -e "    Esegui l'installazione per clonarlo: sudo bash packages/custom/future-os-updater/install.sh"
    fi

    # 2. APT
    echo -e "  ${CYAN}→${RESET} Aggiornamento pacchetti..."
    apt-get update -q 2>&1 | grep -cE '(Get|Hit)' | xargs -I{} echo -e "    {} sorgenti aggiornati" || true

    UPDATES=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst' || true)
    SEC=$(apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep -c 'security' || true)
    FOS=$(apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep -c 'future-os' || true)

    if [ "$UPDATES" -eq 0 ]; then
        echo -e "  ${GREEN}✓${RESET} Tutti i pacchetti sono aggiornati"
    else
        echo -e "  ${YELLOW}•${RESET} ${BOLD}${UPDATES}${RESET} aggiornamenti (${SEC} sicurezza, ${FOS} Future OS)"
        if [ "$full" -eq 1 ]; then
            AUTO_UPGRADE=1 /usr/local/bin/future-os-update
        else
            /usr/local/bin/future-os-update
        fi
        echo -e "  ${GREEN}✓${RESET} Pacchetti aggiornati"
    fi

    echo ""
    if [ -f /var/run/reboot-required ]; then
        echo -e "  ${YELLOW}!${RESET} Riavvio consigliato per completare l'aggiornamento."
    else
        echo -e "  ${GREEN}✓${RESET} Sistema aggiornato."
    fi
    echo ""
}

cmd_status() {
    echo -e ""
    echo -e "  ${CYAN}${BOLD}Stato Future OS${RESET}"
    echo ""

    # Stato repo
    if [ -d "$REPO_DIR/.git" ]; then
        REV=$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "?")
        echo -e "  Repository: ${GREEN}$REPO_DIR${RESET} (HEAD: $REV)"
    else
        echo -e "  Repository: ${YELLOW}non installato in $REPO_DIR${RESET}"
    fi

    # Stato APT
    apt-get update -q &>/dev/null || true
    UPDATES=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst' || true)
    SEC=$(apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep -c 'security' || true)
    FOS=$(apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep -c 'future-os' || true)

    if [ "$UPDATES" -eq 0 ]; then
        echo -e "  Pacchetti:  ${GREEN}sistema aggiornato${RESET}"
    else
        echo -e "  Pacchetti:  ${YELLOW}${UPDATES} disponibili${RESET} (${SEC} sicurezza, ${FOS} Future OS)"
        echo -e "  Esegui: ${BOLD}sudo smart update${RESET}"
    fi

    echo ""
    [ -f "$STAMP" ] && echo -e "  Ultimo aggiornamento: $(cat "$STAMP")" \
                    || echo -e "  Nessun aggiornamento eseguito ancora."

    systemctl is-active --quiet future-os-updater.timer 2>/dev/null && \
        echo -e "  Timer automatico: ${GREEN}attivo${RESET} (ogni giorno alle 03:00)" || \
        echo -e "  Timer automatico: ${YELLOW}non attivo${RESET}"
    echo ""
}

cmd_log() {
    local lines=50
    [ "${1:-}" = "--tail" ] && lines="${2:-50}"
    if [ ! -f "$LOG" ]; then
        echo -e "${YELLOW}Nessun log disponibile ancora.${RESET}"; exit 0
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
    *) echo -e "${RED}Comando sconosciuto: '${1}'${RESET}"; usage; exit 1 ;;
esac
