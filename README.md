# Future OS

Future OS è una distribuzione Linux basata su **Debian Testing**, pensata per la sicurezza, la privacy e l'uso quotidiano.

## Caratteristiche

- Base Debian Testing
- Kernel hardened
- Strumenti di sicurezza preinstallati
- Desktop environment leggero (MATE / KDE)
- Identità visiva originale Future OS
- Aggiornamenti automatici e sicuri

## Aggiornamento del sistema

```bash
# Aggiorna il sistema (sicurezza + pacchetti Future OS)
sudo smart update

# Aggiorna tutto
sudo smart update --full

# Controlla gli aggiornamenti disponibili
smart status

# Vedi il log degli aggiornamenti
smart log
```

L'aggiornamento automatico avviene ogni giorno alle 03:00 (solo sicurezza + pacchetti Future OS).

## Struttura del repository

```
future-os/
├── packages/
│   ├── base/
│   ├── security/
│   ├── desktop/
│   └── custom/
│       ├── future-os-resources/  # Tema, branding, wallpaper, suoni, GRUB
│       └── future-os-updater/    # Auto-aggiornamento e comando smart
├── scripts/
│   ├── build.sh
│   └── install.sh
└── config/
    ├── apt/
    └── grub/
```

## Installazione pacchetti

```bash
# Risorse e tema
sudo bash packages/custom/future-os-resources/install.sh

# Auto-aggiornamento (abilita 'sudo smart update')
sudo bash packages/custom/future-os-updater/install.sh

# Con tema GRUB
sudo APPLY_GRUB=1 bash packages/custom/future-os-resources/install.sh
```
