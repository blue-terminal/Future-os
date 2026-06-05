# Future OS

Future OS è una distribuzione Linux basata su **Debian Testing**, pensata per la sicurezza, la privacy e l'uso quotidiano.

## Caratteristiche

- Base Debian Testing
- Kernel hardened
- Strumenti di sicurezza preinstallati
- Desktop environment leggero (MATE / KDE)
- Identità visiva originale Future OS
- Pacchetti aggiornati e personalizzati

## Struttura del repository

```
future-os/
├── packages/
│   ├── base/                    # Pacchetti di sistema base
│   ├── security/                # Strumenti di sicurezza e pentesting
│   ├── desktop/                 # Ambiente desktop e applicazioni
│   └── custom/
│       └── future-os-resources/  # Pacchetto risorse e branding
├── scripts/
│   ├── build.sh                 # Build dell'immagine ISO
│   └── install.sh               # Installazione guidata
└── config/
    ├── apt/                     # Sorgenti e preferenze APT
    └── grub/                    # Configurazione bootloader
```

## Build

```bash
bash scripts/build.sh
```

## Installazione

```bash
bash scripts/install.sh
```

## Pacchetto risorse

Installa il pacchetto completo di risorse (tema, branding, wallpaper, suoni, GRUB):

```bash
sudo bash packages/custom/future-os-resources/install.sh
```

Per applicare anche il tema GRUB:

```bash
sudo APPLY_GRUB=1 bash packages/custom/future-os-resources/install.sh
```
