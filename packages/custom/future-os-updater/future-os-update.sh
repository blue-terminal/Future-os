#!/bin/bash
# future-os-update - Script di aggiornamento automatico Future OS
set -euo pipefail

LOG=/var/log/future-os/updater.log
LOCK=/var/lock/future-os-update.lock
STAMP=/var/lib/future-os/last-update

mkdir -p "$(dirname "$LOG")" "$(dirname "$STAMP")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

# Evita esecuzioni parallele
exec 9>"$LOCK"
flock -n 9 || { log "SKIP: aggiornamento già in corso"; exit 0; }

log "=== Future OS Auto-Updater avviato ==="

# 1. Controlla connessione di rete
if ! ping -c1 -W3 8.8.8.8 &>/dev/null; then
    log "SKIP: nessuna connessione di rete"
    exit 0
fi

# 2. Aggiorna lista pacchetti
log "Aggiornamento lista pacchetti..."
apt-get update -qq 2>>'$LOG' && log "Lista aggiornata" || { log "ERRORE: apt-get update fallito"; exit 1; }

# 3. Conta pacchetti aggiornabili
UPDATES=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst' || true)
SEC_UPDATES=$(apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep -c 'security' || true)

if [ "$UPDATES" -eq 0 ]; then
    log "Nessun aggiornamento disponibile"
    date -Iseconds > "$STAMP"
    exit 0
fi

log "Trovati $UPDATES aggiornamenti ($SEC_UPDATES di sicurezza)"

# 4. Aggiornamento di sicurezza sempre automatico
if [ "$SEC_UPDATES" -gt 0 ]; then
    log "Installazione aggiornamenti di sicurezza ($SEC_UPDATES)..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
        -o Dpkg::Options::='--force-confdef' \
        -o Dpkg::Options::='--force-confold' \
        $(apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep 'security' | awk '{print $2}') \
        >> "$LOG" 2>&1 && log "Aggiornamenti sicurezza applicati" \
        || log "ATTENZIONE: alcuni aggiornamenti sicurezza falliti"
fi

# 5. Aggiornamenti ordinari (solo se AUTO_UPGRADE=1 o se ci sono solo aggiornamenti futureos)
FUTURE_UPDATES=$(apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep -c 'future-os' || true)
if [ "${AUTO_UPGRADE:-0}" = "1" ] || [ "$FUTURE_UPDATES" -gt 0 ]; then
    log "Installazione aggiornamenti Future OS ($FUTURE_UPDATES pacchetti)..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q \
        -o Dpkg::Options::='--force-confdef' \
        -o Dpkg::Options::='--force-confold' \
        >> "$LOG" 2>&1 && log "Aggiornamento completato" \
        || log "ATTENZIONE: aggiornamento parzialmente fallito"
fi

# 6. Pulizia
apt-get autoremove -y -q >> "$LOG" 2>&1 || true
apt-get autoclean -q     >> "$LOG" 2>&1 || true

# 7. Notifica desktop (se sessione grafica attiva)
if command -v notify-send &>/dev/null; then
    DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u 1000)/bus \
    notify-send \
        --app-name='Future OS Updater' \
        --icon=system-software-update \
        'Aggiornamento completato' \
        "$UPDATES pacchetti aggiornati ($SEC_UPDATES sicurezza)" 2>/dev/null || true
fi

# 8. Controlla se serve riavvio
if [ -f /var/run/reboot-required ]; then
    log "ATTENZIONE: riavvio richiesto per completare l'aggiornamento"
    if command -v notify-send &>/dev/null; then
        DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u 1000)/bus \
        notify-send \
            --app-name='Future OS Updater' \
            --urgency=normal \
            --icon=system-reboot \
            'Riavvio consigliato' \
            'Alcuni aggiornamenti richiedono un riavvio.' 2>/dev/null || true
    fi
fi

date -Iseconds > "$STAMP"
log "=== Aggiornamento completato ==="
