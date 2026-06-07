#!/bin/bash
# Future OS Installer - TUI con whiptail
set -euo pipefail

export TERM=linux
CYAN='\033[1;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'

TITLE="Future OS 1.0 Horizon - Installazione"
LOG=/tmp/future-os-install.log

log()  { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
die()  { whiptail --title "Errore" --msgbox "$1" 10 60; exit 1; }
step() { log "STEP: $1"; }

[ "$(id -u)" -ne 0 ] && { echo -e "${RED}Esegui come root: sudo future-os-install${RESET}"; exit 1; }

clear
echo -e "${CYAN}"
cat << 'LOGO'
  ███████╗██╗   ██╗████████╗██╗   ██╗██████╗ ███████╗    ██████╗ ███████╗
  ██╔════╝██║   ██║╚══██╔══╝██║   ██║██╔══██╗██╔════╝   ██╔═══██╗██╔════╝
  █████╗  ██║   ██║   ██║   ██║   ██║██████╔╝█████╗     ██║   ██║███████╗
  ██╔══╝  ██║   ██║   ██║   ██║   ██║██╔══██╗██╔══╝     ██║   ██║╚════██║
  ██║     ╚██████╔╝   ██║   ╚██████╔╝██║  ██║███████╗   ╚██████╔╝███████║
  ╚═╝      ╚═════╝    ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝    ╚═════╝ ╚══════╝
LOGO
echo -e "${RESET}"

# Benvenuto
whiptail --title "$TITLE" \
    --msgbox "Benvenuto nell'installazione di Future OS 1.0 Horizon!\n\nBased on Debian Testing\nSecurity & Privacy First\n\nPremi OK per continuare." 14 60

# Licenza
whiptail --title "Licenza" \
    --yesno "Future OS è distribuito sotto licenza GNU GPL v3.0.\n\nVuoi continuare con l'installazione?" 10 60 \
    || { echo -e "${YELLOW}Installazione annullata.${RESET}"; exit 0; }

# Selezione disco
step "Selezione disco"
DISKS=$(lsblk -d -n -o NAME,SIZE,MODEL | grep -v loop | awk '{printf "%s\t%s %s\n", $1, $2, $3}')
DISK=$(whiptail --title "Selezione disco" \
    --menu "Seleziona il disco su cui installare Future OS:\n⚠  TUTTI I DATI VERRANNO CANCELLATI" 20 70 8 \
    $(echo "$DISKS" | awk '{print "/dev/"$1, "\""$2"\""}') \
    3>&1 1>&2 2>&3) || die "Nessun disco selezionato."

# Conferma formattazione
whiptail --title "⚠ ATTENZIONE" \
    --yesno "Stai per formattare ${DISK}.\nTUTTI I DATI VERRANNO PERSI DEFINITIVAMENTE.\n\nConfermi?" 10 60 \
    || { echo -e "${YELLOW}Installazione annullata.${RESET}"; exit 0; }

# Utente
step "Configurazione utente"
USERNAME=$(whiptail --title "Nuovo utente" --inputbox "Nome utente (solo minuscole):" 8 50 "utente" 3>&1 1>&2 2>&3) \
    || die "Utente non specificato."
USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
[ -z "$USERNAME" ] && die "Nome utente non valido."

FULLNAME=$(whiptail --title "Nome completo" --inputbox "Nome completo (opzionale):" 8 50 3>&1 1>&2 2>&3) || FULLNAME=""

HOSTNAME_NEW=$(whiptail --title "Hostname" --inputbox "Nome del computer:" 8 50 "future-os" 3>&1 1>&2 2>&3) || HOSTNAME_NEW="future-os"

# Password
PASS1=$(whiptail --title "Password" --passwordbox "Password per $USERNAME:" 8 50 3>&1 1>&2 2>&3) || die "Password non impostata."
PASS2=$(whiptail --title "Password" --passwordbox "Ripeti password:" 8 50 3>&1 1>&2 2>&3) || die "Password non impostata."
[ "$PASS1" != "$PASS2" ] && die "Le password non corrispondono."

ROOTPASS=$(whiptail --title "Password root" --passwordbox "Password root (lascia vuoto = usa stessa password utente):" 8 60 3>&1 1>&2 2>&3) || ROOTPASS=""
[ -z "$ROOTPASS" ] && ROOTPASS="$PASS1"

# Timezone
TIMEZONE=$(whiptail --title "Fuso orario" \
    --menu "Seleziona il fuso orario:" 20 60 8 \
    "Europe/Rome"      "Italia (consigliato)" \
    "Europe/London"    "Londra" \
    "Europe/Paris"     "Parigi" \
    "America/New_York" "New York" \
    "America/Los_Angeles" "Los Angeles" \
    "Asia/Tokyo"       "Tokyo" \
    "UTC"              "UTC" \
    3>&1 1>&2 2>&3) || TIMEZONE="Europe/Rome"

# Locale
LOCALE=$(whiptail --title "Lingua" \
    --menu "Seleziona lingua:" 16 60 6 \
    "it_IT.UTF-8" "Italiano (consigliato)" \
    "en_US.UTF-8" "English" \
    "es_ES.UTF-8" "Español" \
    "fr_FR.UTF-8" "Français" \
    "de_DE.UTF-8" "Deutsch" \
    3>&1 1>&2 2>&3) || LOCALE="it_IT.UTF-8"

# Riepilogo
whiptail --title "Riepilogo installazione" \
    --yesno "Disco:     $DISK\nUtente:    $USERNAME\nHostname:  $HOSTNAME_NEW\nTimezone:  $TIMEZONE\nLocale:    $LOCALE\n\nProcedere con l'installazione?" 16 60 \
    || { echo -e "${YELLOW}Installazione annullata.${RESET}"; exit 0; }

# === INSTALLAZIONE ===
{   
    echo 10; log "Partizionamento $DISK..."
    # Partizione EFI (512MB) + root
    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart ESP fat32 1MiB 513MiB
    parted -s "$DISK" set 1 esp on
    parted -s "$DISK" mkpart primary ext4 513MiB 100%
    echo 20; log "Formattazione..."
    mkfs.fat -F32 "${DISK}1" >> "$LOG" 2>&1
    mkfs.ext4 -L future-os "${DISK}2" >> "$LOG" 2>&1
    echo 30; log "Mount..."
    mount "${DISK}2" /mnt
    mkdir -p /mnt/boot/efi
    mount "${DISK}1" /mnt/boot/efi
    echo 40; log "Copia sistema..."
    rsync -a --exclude=/proc --exclude=/sys --exclude=/dev \
          --exclude=/run --exclude=/mnt --exclude=/tmp \
          / /mnt/ >> "$LOG" 2>&1
    echo 60; log "Configurazione sistema..."
    echo "$HOSTNAME_NEW" > /mnt/etc/hostname
    echo "127.0.1.1 $HOSTNAME_NEW" >> /mnt/etc/hosts
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /mnt/etc/localtime
    echo "LANG=$LOCALE" > /mnt/etc/locale.conf
    echo 70; log "Creazione utente $USERNAME..."
    chroot /mnt useradd -m -G sudo,audio,video,plugdev,netdev \
        -s /bin/bash -c "$FULLNAME" "$USERNAME" >> "$LOG" 2>&1
    echo "$USERNAME:$PASS1" | chroot /mnt chpasswd >> "$LOG" 2>&1
    echo "root:$ROOTPASS" | chroot /mnt chpasswd >> "$LOG" 2>&1
    echo 80; log "Installazione GRUB..."
    chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi \
        --bootloader-id="Future OS" >> "$LOG" 2>&1
    chroot /mnt update-grub >> "$LOG" 2>&1
    echo 90; log "Configurazione finale..."
    # Aggiorna fstab
    genfstab -U /mnt >> /mnt/etc/fstab 2>/dev/null || true
    # Rimuovi autostart welcome dalla sessione installata (solo live)
    rm -f /mnt/etc/skel/.config/autostart/future-os-welcome.desktop
    # Sposta il welcome come icona sul desktop utente
    mkdir -p "/mnt/home/$USERNAME/Desktop"
    cat > "/mnt/home/$USERNAME/Desktop/future-os-welcome.desktop" << DESK
[Desktop Entry]
Type=Application
Name=Benvenuto in Future OS
Exec=xdg-open /usr/share/future-os/welcome.html
Icon=system-software-install
Terminal=false
DESK
    chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME" >> "$LOG" 2>&1
    echo 100
} | whiptail --title "Installazione in corso..." \
    --gauge "Preparazione..." 8 60 0

whiptail --title "Installazione completata!" \
    --msgbox "Future OS è stato installato con successo!\n\nUtente: $USERNAME\nHostname: $HOSTNAME_NEW\n\nRimuovi il supporto di installazione e premi OK per riavviare." 14 60

umount -R /mnt 2>/dev/null || true
reboot
