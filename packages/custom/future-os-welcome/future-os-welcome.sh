#!/bin/bash
# Future OS - App di benvenuto (apre il browser con welcome.html)
xdg-open /usr/share/future-os/welcome.html 2>/dev/null || \
firefox-esr /usr/share/future-os/welcome.html 2>/dev/null || \
chromium /usr/share/future-os/welcome.html 2>/dev/null || true
