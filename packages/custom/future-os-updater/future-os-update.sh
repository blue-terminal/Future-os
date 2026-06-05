#!/bin/bash
# future-os-update - Aggiornamento automatico Future OS (APT + repo)
set -euo pipefail

LOG=/var/log/future-os/updater.log
LOCK=/var/lock/future-os-update.lock
STAMP=/var/lib/future-os/last-update
REPO_DIR=/opt/future-os
REPO_URL=https://github.com/blue-terminal/Future-os.git
REPO_BRANCH=main

mkdir -p "$(dirname "$LOG")" "$(dirname "$STAMP")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

exec 9>"$LOCK"
flock -n 9 || { log "SKIP: aggiornamento già in corso"; exit 0; }

log "=== Future OS Auto-Updater avviato ==="

# --- Rete ---
if ! ping -c1 -W3 8.8.8.8 &>/dev/null; then
    log "SKIP: nessuna connessione di rete"
    exit 0
fi

# === 1. AGGIORNAMENTO REPOSITORY ===
log "--- Sincronizzazione repository ---"
if [ ! -d "$REPO_DIR/.git" ]; then
    log "Clono il repository in $REPO_DIR..."
    git clone --branch "$REPO_BRANCH" --depth=1 "$REPO_URL" "$REPO_DIR" >> "$LOG" 2>&1 \
        && log "Repository clonato" \
        || { log "ERRORE: clone fallito"; }
else
    cd "$REPO_DIR"
    BEFORE=$(git rev-parse HEAD)
    git fetch origin "$REPO_BRANCH" >> "$LOG" 2>&1 || { log "ERRORE: git fetch fallito"; }
    git reset --hard "origin/$REPO_BRANCH" >> "$LOG" 2>&1
    AFTER=$(git rev-parse HEAD)
    if [ "$BEFORE" != "$AFTER" ]; then
        log "Repository aggiornato: $BEFORE -> $AFTER"
        CHANGED=$(git diff --name-only "$BEFORE" "$AFTER" 2>/dev/null || true)
        log "File modificati: $(echo "$CHANGED" | tr '\n' ' ')"
        # Se ci sono nuovi script di installazione pacchetti, li esegue
        if echo "$CHANGED" | grep -q 'packages/custom/.*/install.sh'; then
            log "Rilevati nuovi pacchetti, eseguo installazione..."
            while IFS= read -r f; do
                [[ "$f" =~ packages/custom/.*/install.sh ]] || continue
                log "Installo: $f"
                bash "$REPO_DIR/$f" >> "$LOG" 2>&1 && log "OK: $f" || log "ERRORE: $f"
            done <<< "$CHANGED"
        fi
    else
        log "Repository già aggiornato (HEAD: $AFTER)"
    fi
fi

# === 2. AGGIORNAMENTO APT ===
log "--- Aggiornamento pacchetti APT ---"
apt-get update -qq >> "$LOG" 2>&1 && log "Lista pacchetti aggiornata" \
    || { log "ERRORE: apt-get update fallito"; exit 1; }

UPDATES=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst' || true)
SEC_UPDATES=$(apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep -c 'security' || true)

if [ "$UPDATES" -eq 0 ]; then
    log "Nessun pacchetto APT da aggiornare"
else
    log "Trovati $UPDATES aggiornamenti APT ($SEC_UPDATES sicurezza)"

    if [ "$SEC_UPDATES" -gt 0 ]; then
        log "Installazione aggiornamenti sicurezza..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
            -o Dpkg::Options::='--force-confdef' \
            -o Dpkg::Options::='--force-confold' \
            $(apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep 'security' | awk '{print $2}') \
            >> "$LOG" 2>&1 && log "Aggiornamenti sicurezza applicati" \
            || log "ATTENZIONE: alcuni aggiornamenti sicurezza falliti"
    fi

    FUTURE_UPDATES=$(apt-get -s upgrade 2>/dev/null | grep '^Inst' | grep -c 'future-os' || true)
    if [ "${AUTO_UPGRADE:-0}" = "1" ] || [ "$FUTURE_UPDATES" -gt 0 ]; then
        log "Installazione pacchetti Future OS ($FUTURE_UPDATES)..."
        DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q \
            -o Dpkg::Options::='--force-confdef' \
            -o Dpkg::Options::='--force-confold' \
            >> "$LOG" 2>&1 && log "Aggiornamento APT completato" \
            || log "ATTENZIONE: aggiornamento APT parzialmente fallito"
    fi
fi

apt-get autoremove -y -q >> "$LOG" 2>&1 || true
apt-get autoclean -q     >> "$LOG" 2>&1 || true

# === 3. NOTIFICHE ===
if command -v notify-send &>/dev/null; then
    DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u 1000 2>/dev/null || echo 1000)/bus \
    notify-send \
        --app-name='Future OS Updater' \
        --icon=system-software-update \
        'Sistema aggiornato' \
        "Repository e $UPDATES pacchetti aggiornati" 2>/dev/null || true
fi

if [ -f /var/run/reboot-required ]; then
    log "ATTENZIONE: riavvio richiesto"
    command -v notify-send &>/dev/null && \
    DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u 1000 2>/dev/null || echo 1000)/bus \
    notify-send --app-name='Future OS Updater' --urgency=normal --icon=system-reboot \
        'Riavvio consigliato' 'Alcuni aggiornamenti richiedono un riavvio.' 2>/dev/null || true
fi

date -Iseconds > "$STAMP"
log "=== Aggiornamento completato ==="
