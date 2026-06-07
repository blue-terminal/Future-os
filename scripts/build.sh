#!/bin/bash
# Future OS - Build ISO
# Richiede: live-build, debootstrap, squashfs-tools, xorriso
set -euo pipefail

CYAN='\033[1;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'

VERSION="1.0"
CODENAME="horizon"
ARCH="amd64"
BUILD_DIR="/tmp/future-os-build"
OUTPUT_DIR="$(pwd)/output"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

step() { echo -e "  ${CYAN}=>${RESET} $1"; }
ok()   { echo -e "  ${GREEN}[OK]${RESET} $1"; }
die()  { echo -e "  ${RED}[ERRORE]${RESET} $1"; exit 1; }

[ "$(id -u)" -ne 0 ] && die "Esegui come root: sudo bash scripts/build.sh"

echo -e ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║     Future OS ${VERSION} ${CODENAME} - Build ISO      ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
echo -e ""

# --- Dipendenze ---
step "Verifica dipendenze build..."
for pkg in live-build debootstrap squashfs-tools xorriso isolinux syslinux-common; do
    if ! dpkg -l "$pkg" &>/dev/null; then
        echo -e "    Installazione $pkg..."
        apt-get install -y -q "$pkg"
    fi
done
ok "Dipendenze OK"

# --- Setup directory ---
step "Preparazione directory build in $BUILD_DIR..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"
cd "$BUILD_DIR"
ok "Directory pronti"

# --- Configurazione live-build ---
step "Configurazione live-build..."
lb config \
    --architecture "$ARCH" \
    --distribution "testing" \
    --archive-areas "main contrib non-free non-free-firmware" \
    --debian-installer live \
    --debian-installer-gui false \
    --bootloader grub-efi \
    --binary-images iso-hybrid \
    --iso-volume "Future OS ${VERSION}" \
    --iso-publisher "blue-terminal" \
    --iso-application "Future OS" \
    --memtest none \
    --firmware-binary true \
    --firmware-chroot true \
    --bootappend-live "boot=live components locales=it_IT.UTF-8 keyboard-layouts=it timezone=Europe/Rome hostname=future-os username=user"

ok "live-build configurato"

# --- Pacchetti ---
step "Copia liste pacchetti..."
mkdir -p config/package-lists

# Base
cat > config/package-lists/base.list.chroot << 'EOF'
# Future OS - Base System
systemd
systemd-sysv
dbus
udev
network-manager
network-manager-gnome
wireless-tools
wpasupplicant
firmware-linux
firmware-linux-nonfree
firmware-iwlwifi
firmware-realtek
apt-transport-https
ca-certificates
curl
wget
git
nano
vim
bash-completion
man-db
locales
localepurge
timezone-data
EOF

# Desktop
cat > config/package-lists/desktop.list.chroot << 'EOF'
# Future OS - Desktop
xorg
xserver-xorg
lightdm
lightdm-gtk-greeter
mate-desktop-environment
mate-desktop-environment-extras
mate-tweak
plymouth
plymouth-themes
libreoffice
libreoffice-l10n-it
firefox-esr
vlc
gimp
caja
gedit
mate-terminal
tilix
fonts-noto
fonts-firacode
fonts-jetbrains-mono
papirus-icon-theme
keepassxc
libnotify-bin
python3
python3-pip
EOF

# Sicurezza
cat > config/package-lists/security.list.chroot << 'EOF'
# Future OS - Security Tools
ufw
gufw
fail2ban
clamav
clamtk
apparmor
apparmor-utils
apparmor-profiles
apparmor-profiles-extra
firejail
wireGuard
openvpn
nmap
wireshark
netcat-openbsd
tcpdump
aircrack-ng
john
hydra
gpg
veracrypt
macchanger
tor
torbrowser-launcher
EOF

# Custom
cat > config/package-lists/custom.list.chroot << 'EOF'
# Future OS - Custom packages
unattended-upgrades
apt-listchanges
whiptail
dialog
bashrc-doc
EOF

ok "Liste pacchetti copiate"

# --- Hook: branding e configurazione ---
step "Creazione hook di personalizzazione..."
mkdir -p config/hooks/live

cat > config/hooks/live/0100-future-os-branding.hook.chroot << HOOK
#!/bin/bash
set -e

# OS Release
cat > /etc/os-release << 'EOF'
NAME="Future OS"
VERSION="1.0 (Horizon)"
ID=future-os
ID_LIKE=debian
PRETTY_NAME="Future OS 1.0 Horizon"
VERSION_ID="1.0"
HOME_URL="https://futureos.io/"
SUPPORT_URL="https://futureos.io/support"
BUG_REPORT_URL="https://futureos.io/bugs"
PRIVACY_POLICY_URL="https://futureos.io/privacy"
VERSION_CODENAME=horizon
ANSI_COLOR="1;36"
LOGO=future-os-logo
EOF

# Hostname
echo 'future-os' > /etc/hostname

# MOTD
mkdir -p /etc/update-motd.d
cat > /etc/update-motd.d/10-future-os << 'MOTD'
#!/bin/bash
CYAN='\033[1;36m'; BLUE='\033[1;34m'; RESET='\033[0m'; BOLD='\033[1m'
echo ""
echo -e "  \${CYAN}Future OS 1.0 Horizon\${RESET}  |  \${BLUE}Security & Privacy First\${RESET}"
echo -e "  Kernel: \$(uname -r) | Uptime: \$(uptime -p)"
echo ""
MOTD
chmod +x /etc/update-motd.d/10-future-os

# Welcome app autostart
mkdir -p /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/future-os-welcome.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Benvenuto in Future OS
Exec=/usr/local/bin/future-os-welcome
Icon=system-software-install
Comment=Schermata di benvenuto Future OS
X-GNOME-Autostart-enabled=true
OnlyShowIn=MATE;
EOF

HOOK
chmod +x config/hooks/live/0100-future-os-branding.hook.chroot

cat > config/hooks/live/0200-future-os-theme.hook.chroot << HOOK
#!/bin/bash
set -e

# Imposta tema MATE di default
mkdir -p /etc/skel/.config/mate
gsettings set org.mate.interface gtk-theme 'Materia-dark' 2>/dev/null || true
gsettings set org.mate.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
gsettings set org.mate.interface font-name 'Noto Sans 11' 2>/dev/null || true
gsettings set org.gnome.desktop.background picture-uri '' 2>/dev/null || true

# LightDM
cat > /etc/lightdm/lightdm-gtk-greeter.conf << 'EOF'
[greeter]
theme-name = Materia-dark
icon-theme-name = Papirus-Dark
font-name = Noto Sans 11
clock-format = %H:%M - %A %d %B
panel-position = top
EOF

HOOK
chmod +x config/hooks/live/0200-future-os-theme.hook.chroot

ok "Hook creati"

# --- Copia welcome app ---
step "Copia app di benvenuto..."
mkdir -p config/includes.chroot/usr/local/bin
mkdir -p config/includes.chroot/usr/share/future-os

cp "$REPO_DIR/packages/custom/future-os-welcome/future-os-welcome.sh" \
   config/includes.chroot/usr/local/bin/future-os-welcome
chmod +x config/includes.chroot/usr/local/bin/future-os-welcome

cp "$REPO_DIR/packages/custom/future-os-welcome/welcome.html" \
   config/includes.chroot/usr/share/future-os/welcome.html

# Installer
cp "$REPO_DIR/scripts/install.sh" \
   config/includes.chroot/usr/local/bin/future-os-install
chmod +x config/includes.chroot/usr/local/bin/future-os-install

# Smart updater
cp "$REPO_DIR/packages/custom/future-os-updater/smart.sh" \
   config/includes.chroot/usr/local/bin/smart
cp "$REPO_DIR/packages/custom/future-os-updater/future-os-update.sh" \
   config/includes.chroot/usr/local/bin/future-os-update
chmod +x config/includes.chroot/usr/local/bin/smart
chmod +x config/includes.chroot/usr/local/bin/future-os-update

ok "File copiati"

# --- Build ---
step "Avvio build ISO (potrebbe richiedere 20-40 minuti)..."
echo -e "  ${YELLOW}Log in: /tmp/future-os-build.log${RESET}"
lb build 2>&1 | tee /tmp/future-os-build.log

ISO_FILE=$(find . -name '*.iso' | head -1)
[ -z "$ISO_FILE" ] && die "ISO non trovata dopo il build"

OUT="$OUTPUT_DIR/future-os-${VERSION}-${CODENAME}-${ARCH}.iso"
cp "$ISO_FILE" "$OUT"

SIZE=$(du -sh "$OUT" | cut -f1)
SHA=$(sha256sum "$OUT" | cut -d' ' -f1)

echo -e ""
echo -e "${GREEN}${BOLD}Build completato!${RESET}"
echo -e "  File:   $OUT"
echo -e "  Size:   $SIZE"
echo -e "  SHA256: $SHA"
echo -e ""
echo "$SHA  future-os-${VERSION}-${CODENAME}-${ARCH}.iso" > "$OUTPUT_DIR/SHA256SUMS"
