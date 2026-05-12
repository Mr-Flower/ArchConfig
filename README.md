# 🚀 CachyOS Setup — ThinkPad L14 Gen 5 AMD

Guida completa post-installazione per:

- ottimizzazione energetica
- configurazione fingerprint
- setup software personale
- ambiente desktop KDE
- utilizzo docked/clamshell
- networking con Tailscale

Testato su:

- ThinkPad L14 Gen 5 AMD
- CachyOS
- Arch Linux based systems

---

# 📌 Obiettivi

Questa configurazione permette di:

- ✅ Ottimizzare autonomia e consumi
- ✅ Eliminare il delay di `fprintd` in modalità docked
- ✅ Installare utility essenziali
- ✅ Configurare ambiente desktop coerente
- ✅ Preparare il sistema per sviluppo e gaming
- ✅ Integrare Tailscale nel sistema
- ✅ Avere un setup completo immediatamente operativo

---

# 1. Configurazione TLP (Gestione Energetica)

TLP consente di ottimizzare automaticamente i consumi energetici del ThinkPad.

## Pacchetti Necessari

| Pacchetto | Descrizione |
|---|---|
| `tlp` | Risparmio energetico core |
| `tlp-pd` | Selettore profili energetici |
| `tlp-rdw` | Radio Device Wizard |

## Installazione

```bash
sudo pacman -S tlp tlp-pd tlp-rdw
```

> ⚠️ Nota:
>
> L'installazione di TLP rimuove `power-profiles-daemon`.
>
> Se in futuro disinstallerai TLP:
>
> ```bash
> sudo pacman -S power-profiles-daemon
> ```

---

# 2. Abilitazione Servizi TLP

## Abilitare TLP

```bash
sudo systemctl enable --now tlp.service
```

## Abilitare tlp-pd

```bash
sudo systemctl enable --now tlp-pd.service
```

## Supporto NetworkManager

```bash
sudo systemctl enable NetworkManager-dispatcher.service
```

## Mascherare Servizi in Conflitto

```bash
sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket
```

---

# 3. Installazione di yay (AUR Helper)

CachyOS include spesso `paru`, ma se preferisci `yay`:

## Installare dipendenze

```bash
sudo pacman -S --needed base-devel git
```

## Clonare repository

```bash
git clone https://aur.archlinux.org/yay.git
```

## Compilare e installare

```bash
cd yay
makepkg -si
```

## Pulizia

```bash
cd ..
rm -rf yay
```

---

# 4. Installazione Applicazioni Personali

Una volta configurato `yay`, installare tutte le applicazioni desiderate.

## Installazione Completa

```bash
yay -S \
  tailscale \
  ktailctl \
  visual-studio-code-bin \
  tlpui \
  kvantum \
  materia-kde \
  materia-gtk-theme \
  kvantum-theme-materia \
  vlc \
  zapzap \
  telegram-desktop \
  protonplus
```

---

# 📦 Descrizione Pacchetti

| Pacchetto | Descrizione |
|---|---|
| `tailscale` | VPN mesh basata su WireGuard |
| `ktailctl` | GUI per Tailscale |
| `visual-studio-code-bin` | VS Code ufficiale |
| `tlpui` | GUI per configurare TLP |
| `kvantum` | Engine temi Qt |
| `materia-kde` | Tema KDE Materia |
| `materia-gtk-theme` | Tema GTK Materia |
| `kvantum-theme-materia` | Tema Kvantum Materia |
| `vlc` | Media player |
| `zapzap` | Client WhatsApp desktop |
| `telegram-desktop` | Client Telegram |
| `protonplus` | Gestione Proton/Wine |

---

# 5. Configurazione Tailscale

## Abilitare il servizio

```bash
sudo systemctl enable --now tailscaled
```

## Login a Tailscale

```bash
sudo tailscale up
```

Questo aprirà il browser per autenticare il dispositivo.

## Verifica stato

```bash
tailscale status
```

---

# 6. Personalizzazione Tema KDE

La combinazione:

- `Materia GTK`
- `Materia KDE`
- `Kvantum Materia`

permette di ottenere:

- tema uniforme GTK + Qt
- look moderno
- migliore integrazione KDE Plasma

---

# 7. Fix fprintd Delay in Modalità Docked

Quando il laptop è chiuso (clamshell mode), `fprintd` continua ad attendere il timeout del lettore impronte.

Questa configurazione evita il delay passando immediatamente alla password.

---

# 📌 Problema

PAM tenta di usare il fingerprint reader anche con il portatile chiuso.

Risultato:

- timeout da 10–30 secondi
- login lento
- `sudo` lento
- lock screen lento

---

# ✅ Soluzione

Usare uno script che controlla lo stato del lid e salta `fprintd` se il laptop è chiuso.

---

# 8. Creare Script Controllo Lid

## Creazione file

```bash
sudo nano /usr/local/bin/check_lid.sh
```

## Contenuto

```bash
#!/bin/bash

# Restituisce:
# 0 = lid aperto → usa fingerprint
# 1 = lid chiuso → salta fingerprint

if grep -q "closed" /proc/acpi/button/lid/*/state; then
    exit 1
else
    exit 0
fi
```

## Rendere eseguibile

```bash
sudo chmod +x /usr/local/bin/check_lid.sh
```

---

# 9. Configurare PAM per sudo

Modificare:

```bash
sudo nano /etc/pam.d/sudo
```

## Inserire

```pam
#%PAM-1.0

# Se lo script fallisce (exit 1),
# salta la riga successiva

auth [success=ignore default=1] pam_exec.so quiet /usr/local/bin/check_lid.sh
auth sufficient pam_fprintd.so

auth include system-auth
```

---

# 10. Configurare PAM Globale

Modificare:

```bash
sudo nano /etc/pam.d/system-auth
```

## Inserire nella sezione auth

```pam
#%PAM-1.0

auth required pam_faillock.so preauth

# Controllo lid per fprintd
auth [success=ignore default=1] pam_exec.so quiet /usr/local/bin/check_lid.sh
auth sufficient pam_fprintd.so

# Resto configurazione
auth [success=1 default=bad] pam_unix.so try_first_pass nullok
```

---

# 11. Verifica Configurazione fprintd

## Laptop aperto

```bash
sudo ls
```

Dovrebbe richiedere l'impronta.

---

## Laptop chiuso (Docked)

```bash
sudo ls
```

Dovrebbe richiedere immediatamente la password.

---

# 12. Debug Lid State

Verificare stato ACPI:

```bash
cat /proc/acpi/button/lid/*/state
```

## Output esempio

### Aperto

```text
state:      open
```

### Chiuso

```text
state:      closed
```

---

# 🔋 Verifica TLP

## Stato servizio

```bash
sudo tlp-stat -s
```

## Batteria

```bash
sudo tlp-stat -b
```

## Consumi

```bash
sudo tlp-stat -p
```

---

# 🛠️ Utility Consigliate

## Firmware Lenovo

```bash
sudo pacman -S fwupd
```

Aggiornamento firmware:

```bash
sudo fwupdmgr refresh
sudo fwupdmgr get-updates
sudo fwupdmgr update
```

---

## Bluetooth

```bash
sudo pacman -S bluez bluez-utils
sudo systemctl enable --now bluetooth
```

---

## Flatpak

```bash
sudo pacman -S flatpak
```

Aggiungere Flathub:

```bash
flatpak remote-add --if-not-exists flathub \
https://flathub.org/repo/flathub.flatpakrepo
```

---

# ✅ Setup Finale

| Categoria | Stato |
|---|---|
| Power management | Ottimizzato |
| Fingerprint docked fix | Configurato |
| KDE Theme | Configurato |
| Development tools | Installati |
| Messaging apps | Installate |
| Gaming tools | Installati |
| Tailscale | Configurato |
| AUR helper | Configurato |

---

# ⚠️ Note

- Testato su ThinkPad L14 Gen 5 AMD
- Compatibile con CachyOS / Arch Linux
- Alcuni pacchetti provengono da AUR
- Riavvio consigliato dopo setup completo
- Alcuni laptop usano percorsi ACPI differenti

---

# 📚 Riferimenti Utili

| Componente | Tool |
|---|---|
| Power management | `tlp` |
| Fingerprint | `fprintd` |
| VPN mesh | `tailscale` |
| GUI Tailscale | `ktailctl` |
| Firmware updates | `fwupd` |
| GUI TLP | `tlpui` |
| Gaming Proton | `protonplus` |

---

# 🚀 Possibili Miglioramenti Futuri

- Bootstrap automatico via script
- Dotfiles personalizzati
- Backup con Timeshift
- Setup Docker/Podman
- Ottimizzazioni Wayland
- Auto-install codec e driver
- Hook suspend/resume
- Configurazione automatica KDE