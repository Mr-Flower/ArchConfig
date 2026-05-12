# 🚀 CachyOS Setup — ThinkPad L14 Gen 5 AMD

Guida completa post-installazione per ThinkPad L14 Gen 5 AMD con CachyOS / sistemi Arch Linux based.

La guida copre:

- ottimizzazione energetica con TLP;
- configurazione fingerprint con fallback password in modalità docked/clamshell;
- installazione software personale;
- ambiente KDE Plasma coerente;
- uso con dock, monitor esterno e coperchio chiuso;
- networking con Tailscale;
- backup/snapshot;
- sviluppo, container e gaming;
- codec, firmware, driver e ottimizzazioni Wayland;
- bootstrap automatico tramite script.

---

## ✅ Hardware e sistemi target

Testato / pensato per:

| Voce | Valore |
|---|---|
| Laptop | ThinkPad L14 Gen 5 AMD |
| Distribuzione | CachyOS |
| Base | Arch Linux |
| Desktop | KDE Plasma |
| Display server | Wayland consigliato |
| Modalità d’uso | laptop + dock/clamshell |

Compatibile anche con altri ThinkPad AMD recenti, con eventuali adattamenti per fingerprint, gestione lid e profili energetici.

---

## 📌 Obiettivi della configurazione

Questa configurazione permette di:

- ottimizzare autonomia e consumi;
- usare TLP al posto di `power-profiles-daemon`;
- gestire meglio batteria e soglie di carica;
- eliminare il delay di `fprintd` quando il laptop è chiuso;
- mantenere login, `sudo` e lock screen rapidi anche in modalità docked;
- installare utility essenziali per lavoro, comunicazione, sviluppo e gaming;
- configurare KDE con tema uniforme Qt/GTK;
- integrare Tailscale nel sistema;
- predisporre backup/snapshot;
- preparare Docker/Podman;
- configurare codec, firmware e hardware acceleration;
- avere uno script di bootstrap riutilizzabile.

---

## ⚠️ Avvertenze importanti

Prima di modificare PAM, TLP, logind o boot/snapshot:

1. tieni aperta una sessione terminale già autenticata;
2. fai backup dei file PAM;
3. verifica di poter accedere da TTY con `Ctrl + Alt + F3`;
4. non riavviare finché `sudo` e login non sono stati testati;
5. usa Timeshift o Snapper prima delle modifiche invasive.

Modificare PAM in modo errato può bloccare `sudo`, login grafico o lock screen.

---

# 1. Gestione energetica con TLP

TLP consente di ottimizzare automaticamente i consumi energetici del ThinkPad.

## 1.1 Pacchetti necessari

| Pacchetto | Descrizione |
|---|---|
| `tlp` | risparmio energetico core |
| `tlp-pd` | integrazione profili energetici |
| `tlp-rdw` | Radio Device Wizard |
| `tlpui` | interfaccia grafica per TLP, opzionale |

Installazione:

```bash
sudo pacman -S --needed tlp tlp-pd tlp-rdw
```

Nota: l’installazione di TLP rimuove `power-profiles-daemon`.

Se in futuro disinstalli TLP:

```bash
sudo pacman -S power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon.service
```

## 1.2 Abilitare i servizi

```bash
sudo systemctl enable --now tlp.service
sudo systemctl enable --now tlp-pd.service
sudo systemctl enable NetworkManager-dispatcher.service
```

Mascherare i servizi rfkill in conflitto:

```bash
sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket
```

## 1.3 Verifica TLP

```bash
sudo tlp-stat -s
sudo tlp-stat -b
sudo tlp-stat -p
```

# 2. Modalità docked / clamshell

La modalità clamshell prevede laptop chiuso, dock o alimentatore collegato, monitor esterno, tastiera e mouse esterni.

## 2.1 Comportamento del coperchio

Creare un override per `systemd-logind`:

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudo nano /etc/systemd/logind.conf.d/10-clamshell-docked.conf
```

Contenuto:

```ini
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
```

Questa configurazione mantiene la sospensione normale quando il laptop è usato da solo, ma evita la sospensione automatica quando il sistema è docked o rileva display esterni.

Applicare con riavvio:

```bash
sudo reboot
```

In alternativa, riavviare `systemd-logind`, ma è meno consigliato perché può terminare sessioni utente:

```bash
sudo systemctl restart systemd-logind
```

## 2.2 Impostazioni KDE

In KDE Plasma:

```text
Impostazioni di sistema → Alimentazione → Risparmio energetico
```

Configurare:

| Scenario | Azione consigliata |
|---|---|
| batteria | sospensione alla chiusura coperchio |
| alimentatore | sospensione o blocco, secondo preferenza |
| docked / monitor esterno | non sospendere alla chiusura |

Verificare anche:

```text
Impostazioni di sistema → Schermo e monitor
```

Impostare il monitor esterno come primario, se necessario.

---

# 3. Fingerprint con fprintd

## 3.1 Installazione

```bash
sudo pacman -S --needed fprintd
```

Verificare il lettore:

```bash
fprintd-list "$USER"
```

Registrare impronta:

```bash
fprintd-enroll
```

Verificare:

```bash
fprintd-verify
```

Eliminare impronte, se necessario:

```bash
fprintd-delete "$USER"
```

---

# 4. Fix delay fprintd in modalità docked

## 4.1 Problema

Quando il laptop è chiuso, PAM può tentare comunque l’autenticazione tramite lettore impronte.

Risultato:

- timeout da 10–30 secondi;
- `sudo` lento;
- lock screen lento;
- login lento;
- uso docked poco fluido.

## 4.2 Soluzione

Creare uno script che verifica lo stato del lid:

- lid aperto → usa fingerprint;
- lid chiuso → salta fingerprint e passa subito alla password.

---

## 4.3 Creare lo script `check_lid.sh`

```bash
sudo nano /usr/local/bin/check_lid.sh
```

Contenuto:

```bash
#!/usr/bin/env bash

# Exit code:
# 0 = lid aperto/non rilevato -> consenti fingerprint
# 1 = lid chiuso -> salta fingerprint

if grep -qi "closed" /proc/acpi/button/lid/*/state 2>/dev/null; then
    exit 1
fi

exit 0
```

Rendere eseguibile:

```bash
sudo chmod 755 /usr/local/bin/check_lid.sh
```

Test:

```bash
/usr/local/bin/check_lid.sh
echo $?
```

Interpretazione:

| Stato | Exit code |
|---|---|
| coperchio aperto | `0` |
| coperchio chiuso | `1` |
| stato non rilevato | `0` |

Verificare ACPI manualmente:

```bash
cat /proc/acpi/button/lid/*/state
```

---

# 5. Configurazione PAM per fingerprint

## Strategia consigliata

Usare una sola configurazione globale in `/etc/pam.d/system-auth`.

Non duplicare la configurazione anche in `/etc/pam.d/sudo`, salvo necessità specifiche.

---

## 5.1 Backup PAM

```bash
sudo cp /etc/pam.d/system-auth /etc/pam.d/system-auth.bak.$(date +%F-%H%M)
sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.bak.$(date +%F-%H%M)
```

---

## 5.2 Metodo A — configurazione globale consigliata

Modificare:

```bash
sudo nano /etc/pam.d/system-auth
```

Nella sezione `auth`, inserire le due righe del controllo lid immediatamente prima della riga `pam_unix.so`.

Esempio:

```pam
#%PAM-1.0

auth       required                    pam_faillock.so      preauth

# Fingerprint solo se il lid è aperto.
# Se check_lid.sh restituisce exit 1, viene saltata la riga pam_fprintd.so.
auth       [success=ignore default=1]   pam_exec.so quiet /usr/local/bin/check_lid.sh
auth       sufficient                  pam_fprintd.so

auth       [success=1 default=bad]      pam_unix.so          try_first_pass nullok
auth       [default=die]               pam_faillock.so      authfail
auth       optional                    pam_permit.so
auth       required                    pam_env.so
```

Non sostituire l’intero file se la tua configurazione è diversa. Inserisci solo le due righe:

```pam
auth       [success=ignore default=1]   pam_exec.so quiet /usr/local/bin/check_lid.sh
auth       sufficient                  pam_fprintd.so
```

prima della riga principale `pam_unix.so`.

---

## 5.3 Verificare `/etc/pam.d/sudo`

Il file `/etc/pam.d/sudo` dovrebbe continuare a includere `system-auth`.

Esempio minimale:

```pam
#%PAM-1.0
auth       include      system-auth
account    include      system-auth
session    include      system-auth
```

Se `sudo` contiene già `pam_fprintd.so`, rimuovere la duplicazione per evitare doppie richieste fingerprint.

---

## 5.4 Metodo B — solo `sudo`, alternativa

Usare questo metodo solo se vuoi il fingerprint esclusivamente per `sudo`.

Modificare:

```bash
sudo nano /etc/pam.d/sudo
```

Esempio:

```pam
#%PAM-1.0

auth       [success=ignore default=1]   pam_exec.so quiet /usr/local/bin/check_lid.sh
auth       sufficient                  pam_fprintd.so

auth       include                     system-auth
account    include                     system-auth
session    include                     system-auth
```

In questo caso non aggiungere `pam_fprintd.so` in `system-auth`.

---

## 5.5 Test

Con laptop aperto:

```bash
sudo -k
sudo ls
```

Dovrebbe richiedere impronta o password fallback.

Con laptop chiuso / docked:

```bash
sudo -k
sudo ls
```

Dovrebbe richiedere immediatamente la password, senza timeout fingerprint.

---

## 5.6 Recovery in caso di errore PAM

Da una TTY o live USB, ripristinare il backup:

```bash
sudo cp /etc/pam.d/system-auth.bak.DATA /etc/pam.d/system-auth
sudo cp /etc/pam.d/sudo.bak.DATA /etc/pam.d/sudo
```

Se `sudo` non funziona ma hai una shell root aperta, usa direttamente `cp`.

---

# 6. Installazione AUR helper `yay`

CachyOS include spesso `paru`. Verificare:

```bash
command -v paru
command -v yay
```

Se `paru` è già presente, puoi usarlo al posto di `yay`.

## 6.1 Installare dipendenze

```bash
sudo pacman -S --needed base-devel git
```

## 6.2 Installare `yay`

```bash
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ..
rm -rf yay
```

## 6.3 Buone pratiche AUR

Prima di installare pacchetti AUR:

```bash
yay -Syu
```

Durante l’installazione:

- leggere il `PKGBUILD`;
- non usare `--skipinteg`;
- evitare pacchetti AUR non mantenuti;
- preferire pacchetti dai repository ufficiali quando disponibili.

---

# 7. Installazione applicazioni personali

## 7.1 Pacchetti da repository ufficiali

```bash
sudo pacman -S --needed \
  tailscale \
  telegram-desktop \
  vlc \
  kvantum \
  materia-kde \
  materia-gtk-theme \
  kvantum-theme-materia \
  fwupd \
  bluez \
  bluez-utils \
  flatpak \
  fprintd \
  git \
  base-devel \
  stow
```

## 7.2 Pacchetti AUR / installabili con helper

```bash
yay -S --needed \
  ktailctl \
  visual-studio-code-bin \
  tlpui \
  zapzap \
  protonplus
```

## 7.3 Descrizione pacchetti

| Pacchetto | Descrizione |
|---|---|
| `tailscale` | VPN mesh basata su WireGuard |
| `ktailctl` | GUI per Tailscale |
| `visual-studio-code-bin` | VS Code ufficiale Microsoft |
| `tlpui` | GUI per TLP |
| `kvantum` | engine temi Qt |
| `materia-kde` | tema KDE Materia |
| `materia-gtk-theme` | tema GTK Materia |
| `kvantum-theme-materia` | tema Kvantum Materia |
| `vlc` | media player |
| `zapzap` | client WhatsApp desktop |
| `telegram-desktop` | client Telegram |
| `protonplus` | gestione Proton/Wine |
| `fwupd` | aggiornamenti firmware |
| `flatpak` | runtime applicazioni sandboxed |
| `stow` | gestione dotfiles |

---

# 8. Configurazione Tailscale

## 8.1 Abilitare servizio

```bash
sudo systemctl enable --now tailscaled.service
```

## 8.2 Login

```bash
sudo tailscale up
```

Il terminale mostrerà un link per autenticare il dispositivo.

## 8.3 Verifica

```bash
tailscale status
tailscale ip
```

## 8.4 Opzioni utili

Forzare nuova autenticazione:

```bash
sudo tailscale up --force-reauth
```

Abilitare Tailscale SSH:

```bash
sudo tailscale set --ssh
```

Se Tailscale crea conflitti DNS:

```bash
sudo tailscale up --accept-dns=false
```

## 8.5 KTailctl

Avviare:

```bash
ktailctl
```

Per avvio automatico:

```text
Impostazioni di sistema → Avvio e spegnimento → Avvio automatico
```

Aggiungere `ktailctl`.

---

# 9. KDE Plasma: tema, coerenza grafica e Wayland

## 9.1 Tema Materia + Kvantum

Pacchetti:

```bash
sudo pacman -S --needed kvantum materia-kde materia-gtk-theme kvantum-theme-materia
```

Aprire:

```bash
kvantummanager
```

Selezionare un tema Materia, ad esempio:

```text
Materia
MateriaDark
MateriaLight
```

Poi in KDE:

```text
Impostazioni di sistema → Aspetto
```

Configurare:

| Area | Valore consigliato |
|---|---|
| Tema globale | Materia o Breeze Dark |
| Stile applicazioni | Kvantum |
| Colori | Materia Dark / Breeze Dark |
| Icone | Breeze o Papirus |
| GTK | Materia GTK |
| Decorazioni finestre | Materia / Breeze |

Installazione opzionale Papirus:

```bash
sudo pacman -S --needed papirus-icon-theme
```

## 9.2 Verificare sessione Wayland

```bash
echo "$XDG_SESSION_TYPE"
```

Output atteso:

```text
wayland
```

Se sei in X11, selezionare sessione Plasma Wayland da SDDM prima del login.

# 10. Firmware Lenovo

Installazione:

```bash
sudo pacman -S --needed fwupd
```

Abilitare servizio, se non già attivo:

```bash
sudo systemctl enable --now fwupd.service
```

Aggiornare firmware:

```bash
sudo fwupdmgr refresh
sudo fwupdmgr get-updates
sudo fwupdmgr update
```

Dopo update firmware, riavviare.

---

# 11. Bluetooth

Installazione:

```bash
sudo pacman -S --needed bluez bluez-utils
```

Abilitare:

```bash
sudo systemctl enable --now bluetooth.service
```

Verifica:

```bash
bluetoothctl
```

Comandi base in `bluetoothctl`:

```text
power on
agent on
default-agent
scan on
pair XX:XX:XX:XX:XX:XX
trust XX:XX:XX:XX:XX:XX
connect XX:XX:XX:XX:XX:XX
```

---

# 12. Flatpak e Flathub

Installazione:

```bash
sudo pacman -S --needed flatpak
```
---
