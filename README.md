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

# 1. Aggiornamento iniziale del sistema

Eseguire prima un aggiornamento completo:

```bash
sudo pacman -Syu
```

Verificare kernel, sessione grafica e filesystem:

```bash
uname -a
echo "$XDG_SESSION_TYPE"
lsblk -f
```

Controllare servizi falliti:

```bash
systemctl --failed
```

---

# 2. Snapshot / backup prima del setup

## 2.1 Verificare se CachyOS usa già Snapper

Le installazioni recenti di CachyOS con Btrfs possono includere già una configurazione Snapper/grub-btrfs. Verificare:

```bash
sudo snapper list-configs
sudo snapper list
```

Se Snapper è già configurato, creare uno snapshot manuale prima di procedere:

```bash
sudo snapper create --description "pre-post-install-setup"
```

## 2.2 Alternativa: Timeshift

Se preferisci Timeshift o se usi un layout più semplice:

```bash
sudo pacman -S --needed timeshift
```

Avvio GUI:

```bash
sudo timeshift-gtk
```

Con Btrfs, Timeshift richiede un layout subvolume compatibile. Se non viene rilevato correttamente, usare Snapper o modalità RSYNC.

---

# 3. Gestione energetica con TLP

TLP consente di ottimizzare automaticamente i consumi energetici del ThinkPad.

## 3.1 Pacchetti necessari

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

## 3.2 Abilitare i servizi

```bash
sudo systemctl enable --now tlp.service
sudo systemctl enable --now tlp-pd.service
sudo systemctl enable NetworkManager-dispatcher.service
```

Mascherare i servizi rfkill in conflitto:

```bash
sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket
```

## 3.3 Verifica TLP

```bash
sudo tlp-stat -s
sudo tlp-stat -b
sudo tlp-stat -p
```

## 3.4 Soglie batteria ThinkPad

Verificare il nome della batteria:

```bash
ls /sys/class/power_supply/
```

Di solito il ThinkPad espone `BAT0`.

Creare un file dedicato:

```bash
sudo nano /etc/tlp.d/01-thinkpad-battery.conf
```

Contenuto consigliato:

```ini
# Soglie conservative per uso docked/fisso.
# Modificare in base alle proprie abitudini.

START_CHARGE_THRESH_BAT0=75
STOP_CHARGE_THRESH_BAT0=80
```

Applicare:

```bash
sudo tlp start
sudo tlp-stat -b
```

Per caricare temporaneamente al 100%:

```bash
sudo tlp fullcharge BAT0
```

---

# 4. Modalità docked / clamshell

La modalità clamshell prevede laptop chiuso, dock o alimentatore collegato, monitor esterno, tastiera e mouse esterni.

## 4.1 Comportamento del coperchio

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

## 4.2 Impostazioni KDE

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

# 5. Fingerprint con fprintd

## 5.1 Installazione

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

# 6. Fix delay fprintd in modalità docked

## 6.1 Problema

Quando il laptop è chiuso, PAM può tentare comunque l’autenticazione tramite lettore impronte.

Risultato:

- timeout da 10–30 secondi;
- `sudo` lento;
- lock screen lento;
- login lento;
- uso docked poco fluido.

## 6.2 Soluzione

Creare uno script che verifica lo stato del lid:

- lid aperto → usa fingerprint;
- lid chiuso → salta fingerprint e passa subito alla password.

---

## 6.3 Creare lo script `check_lid.sh`

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

# 7. Configurazione PAM per fingerprint

## Strategia consigliata

Usare una sola configurazione globale in `/etc/pam.d/system-auth`.

Non duplicare la configurazione anche in `/etc/pam.d/sudo`, salvo necessità specifiche.

---

## 7.1 Backup PAM

```bash
sudo cp /etc/pam.d/system-auth /etc/pam.d/system-auth.bak.$(date +%F-%H%M)
sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.bak.$(date +%F-%H%M)
```

---

## 7.2 Metodo A — configurazione globale consigliata

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

## 7.3 Verificare `/etc/pam.d/sudo`

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

## 7.4 Metodo B — solo `sudo`, alternativa

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

## 7.5 Test

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

## 7.6 Recovery in caso di errore PAM

Da una TTY o live USB, ripristinare il backup:

```bash
sudo cp /etc/pam.d/system-auth.bak.DATA /etc/pam.d/system-auth
sudo cp /etc/pam.d/sudo.bak.DATA /etc/pam.d/sudo
```

Se `sudo` non funziona ma hai una shell root aperta, usa direttamente `cp`.

---

# 8. Installazione AUR helper `yay`

CachyOS include spesso `paru`. Verificare:

```bash
command -v paru
command -v yay
```

Se `paru` è già presente, puoi usarlo al posto di `yay`.

## 8.1 Installare dipendenze

```bash
sudo pacman -S --needed base-devel git
```

## 8.2 Installare `yay`

```bash
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ..
rm -rf yay
```

## 8.3 Buone pratiche AUR

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

# 9. Installazione applicazioni personali

## 9.1 Pacchetti da repository ufficiali

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

## 9.2 Pacchetti AUR / installabili con helper

```bash
yay -S --needed \
  ktailctl \
  visual-studio-code-bin \
  tlpui \
  zapzap \
  protonplus
```

## 9.3 Descrizione pacchetti

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

# 10. Configurazione Tailscale

## 10.1 Abilitare servizio

```bash
sudo systemctl enable --now tailscaled.service
```

## 10.2 Login

```bash
sudo tailscale up
```

Il terminale mostrerà un link per autenticare il dispositivo.

## 10.3 Verifica

```bash
tailscale status
tailscale ip
```

## 10.4 Opzioni utili

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

## 10.5 KTailctl

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

# 11. KDE Plasma: tema, coerenza grafica e Wayland

## 11.1 Tema Materia + Kvantum

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

## 11.2 Verificare sessione Wayland

```bash
echo "$XDG_SESSION_TYPE"
```

Output atteso:

```text
wayland
```

Se sei in X11, selezionare sessione Plasma Wayland da SDDM prima del login.

## 11.3 Variabili ambiente Wayland

Creare:

```bash
mkdir -p ~/.config/environment.d
nano ~/.config/environment.d/90-wayland-apps.conf
```

Contenuto:

```ini
# Firefox/Thunderbird su Wayland
MOZ_ENABLE_WAYLAND=1

# Electron/Chromium recenti: usa backend automatico
ELECTRON_OZONE_PLATFORM_HINT=auto

# Integrazione tema Qt/KDE
QT_QPA_PLATFORMTHEME=kde
```

Applicare con logout/login.

## 11.4 Scaling e monitor esterno

In KDE:

```text
Impostazioni di sistema → Schermo e monitor → Configurazione schermo
```

Per monitor 2K/4K usare preferibilmente scaling KDE nativo, evitando variabili globali aggressive come `QT_SCALE_FACTOR`, salvo casi specifici.

---

# 12. Firmware Lenovo

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

# 13. Bluetooth

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

# 14. Flatpak e Flathub

Installazione:

```bash
sudo pacman -S --needed flatpak
```

Aggiungere Flathub:

```bash
flatpak remote-add --if-not-exists flathub \
https://flathub.org/repo/flathub.flatpakrepo
```

Verifica:

```bash
flatpak remotes
```

---

# 15. Codec, multimedia e hardware acceleration

## 15.1 Codec principali

```bash
sudo pacman -S --needed \
  ffmpeg \
  gst-plugins-base \
  gst-plugins-good \
  gst-plugins-bad \
  gst-plugins-ugly \
  gst-libav
```

## 15.2 AMD GPU / VA-API / Vulkan

Per ThinkPad AMD:

```bash
sudo pacman -S --needed \
  mesa \
  vulkan-radeon \
  libva-mesa-driver \
  mesa-vdpau \
  libva-utils \
  vulkan-tools
```

Verifica VA-API:

```bash
vainfo
```

Verifica Vulkan:

```bash
vulkaninfo --summary
```

## 15.3 Browser Chromium-based

Per Chrome/Chromium/Edge/Brave, verificare l’hardware acceleration dalle pagine interne del browser, ad esempio:

```text
chrome://gpu
edge://gpu
brave://gpu
```

---

# 16. Hardware detection CachyOS

CachyOS include `chwd`, utile per rilevare e installare profili hardware.

Verificare profili disponibili:

```bash
chwd --list-all
```

Auto-configurazione:

```bash
sudo chwd -a
```

Usare questa funzione con attenzione su sistemi già configurati. Dopo l’auto-configurazione, controllare eventuali pacchetti installati e riavviare.

---

# 17. Sviluppo

## 17.1 Tool base

```bash
sudo pacman -S --needed \
  git \
  base-devel \
  cmake \
  ninja \
  python \
  python-pip \
  nodejs \
  npm \
  jdk-openjdk
```

## 17.2 Configurazione Git

```bash
git config --global user.name "Nome Cognome"
git config --global user.email "email@example.com"
git config --global init.defaultBranch main
git config --global pull.rebase false
```

## 17.3 VS Code

Installazione:

```bash
yay -S --needed visual-studio-code-bin
```

Estensioni utili:

```bash
code --install-extension ms-python.python
code --install-extension ms-vscode.cpptools
code --install-extension redhat.java
code --install-extension dbaeumer.vscode-eslint
code --install-extension esbenp.prettier-vscode
```

---

# 18. Docker

## 18.1 Installazione

```bash
sudo pacman -S --needed docker docker-compose
```

## 18.2 Abilitare servizio

```bash
sudo systemctl enable --now docker.service
```

## 18.3 Uso senza sudo

```bash
sudo usermod -aG docker "$USER"
```

Effettuare logout/login oppure:

```bash
newgrp docker
```

Verifica:

```bash
docker run hello-world
```

Nota di sicurezza: il gruppo `docker` equivale sostanzialmente ad accesso root. Per ambienti più isolati, valutare Podman rootless.

---

# 19. Podman rootless

## 19.1 Installazione

```bash
sudo pacman -S --needed \
  podman \
  podman-compose \
  buildah \
  skopeo \
  fuse-overlayfs \
  slirp4netns \
  passt
```

## 19.2 Configurazione UID/GID subordinati

Verificare:

```bash
grep "$USER" /etc/subuid /etc/subgid
```

Se non presenti:

```bash
sudo touch /etc/subuid /etc/subgid
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USER"
```

Applicare:

```bash
podman system migrate
```

Verifica:

```bash
podman info
podman run --rm hello-world
```

## 19.3 Alias Docker opzionale

Se vuoi usare comandi compatibili Docker:

```bash
sudo pacman -S --needed podman-docker
```

---

# 20. Gaming

## 20.1 Pacchetti gaming CachyOS

CachyOS fornisce meta-pacchetti dedicati:

```bash
sudo pacman -S --needed cachyos-gaming-meta cachyos-gaming-applications
```

Questi possono includere librerie, Steam, Lutris, Heroic Games Launcher, MangoHud, Gamescope e altri tool.

## 20.2 ProtonPlus

```bash
yay -S --needed protonplus
```

Usare ProtonPlus per gestire:

- Proton-GE;
- Wine-GE;
- versioni custom di Proton;
- installazioni per Steam, Lutris e Heroic.

## 20.3 Verifica Vulkan

```bash
vulkaninfo --summary
```

## 20.4 MangoHud

Se installato:

```bash
mangohud glxgears
```

In Steam, opzione di lancio:

```text
mangohud %command%
```

---

# 21. Hook suspend/resume

Gli hook systemd in `/usr/lib/systemd/system-sleep/` consentono di eseguire azioni prima e dopo sospensione/ibernazione.

Creare:

```bash
sudo nano /usr/lib/systemd/system-sleep/99-thinkpad-resume.sh
```

Contenuto sicuro, solo logging:

```bash
#!/usr/bin/env bash

case "$1/$2" in
  pre/*)
    logger -t thinkpad-sleep "Entering $2"
    ;;
  post/*)
    logger -t thinkpad-sleep "Resumed from $2"

    # Sbloccare solo se necessario:
    # systemctl --no-block try-restart bluetooth.service
    # systemctl --no-block try-restart tailscaled.service
    ;;
esac
```

Rendere eseguibile:

```bash
sudo chmod 755 /usr/lib/systemd/system-sleep/99-thinkpad-resume.sh
```

Verificare log:

```bash
journalctl -t thinkpad-sleep -b
```

---

# 22. Dotfiles personalizzati

## 22.1 Installare GNU Stow

```bash
sudo pacman -S --needed stow
```

## 22.2 Struttura consigliata

```text
~/.dotfiles/
├── git/
│   └── .gitconfig
├── shell/
│   ├── .bashrc
│   └── .zshrc
├── kde/
│   └── .config/
│       ├── konsolerc
│       ├── kdeglobals
│       └── kglobalshortcutsrc
└── vscode/
    └── .config/
        └── Code/
            └── User/
                ├── settings.json
                └── keybindings.json
```

## 22.3 Applicare dotfiles

```bash
cd ~/.dotfiles
stow git
stow shell
stow kde
stow vscode
```

## 22.4 Backup configurazione KDE

Creare cartella backup:

```bash
mkdir -p ~/Backups/kde-config
```

Copiare configurazioni principali:

```bash
cp ~/.config/kdeglobals ~/Backups/kde-config/
cp ~/.config/kglobalshortcutsrc ~/Backups/kde-config/
cp ~/.config/kscreenlockerrc ~/Backups/kde-config/ 2>/dev/null || true
cp ~/.config/konsolerc ~/Backups/kde-config/ 2>/dev/null || true
```

---

# 23. Automazione KDE

Alcune impostazioni KDE si possono automatizzare via CLI, ma non tutte sono stabili tra versioni Plasma.

## 23.1 Elencare temi globali

```bash
lookandfeeltool --list
```

Applicare un tema, esempio Breeze Dark:

```bash
lookandfeeltool -a org.kde.breezedark.desktop
```

Per Materia, usare il nome mostrato da:

```bash
lookandfeeltool --list | grep -i materia
```

## 23.2 Applicare colori

Elenco schemi:

```bash
plasma-apply-colorscheme --list-schemes
```

Applicare:

```bash
plasma-apply-colorscheme BreezeDark
```

## 23.3 Applicare Kvantum

Elencare temi disponibili:

```bash
ls /usr/share/Kvantum
```

Applicare da GUI:

```bash
kvantummanager
```

In alcune installazioni è disponibile:

```bash
kvantummanager --set MateriaDark
```

Se il comando non funziona, usare la GUI.

---

# 24. Manutenzione sistema

## 24.1 Aggiornamento completo

```bash
yay -Syu
```

oppure, se usi `paru`:

```bash
paru -Syu
```

## 24.2 Pulizia cache pacman

Mostrare cache:

```bash
du -sh /var/cache/pacman/pkg
```

Pulizia conservativa:

```bash
sudo paccache -r
```

Installare `pacman-contrib`, se necessario:

```bash
sudo pacman -S --needed pacman-contrib
```

## 24.3 Pacchetti orfani

```bash
pacman -Qtdq
```

Rimuovere orfani:

```bash
sudo pacman -Rns $(pacman -Qtdq)
```

Se non ci sono orfani, il comando può restituire errore. È normale.

## 24.4 File `.pacnew`

Dopo aggiornamenti importanti:

```bash
sudo pacdiff
```

Se manca `pacdiff`:

```bash
sudo pacman -S --needed pacman-contrib
```

---

# 25. Bootstrap automatico

Questa sezione implementa uno script riutilizzabile per automatizzare la parte non distruttiva del setup.

Lo script:

- aggiorna il sistema;
- installa pacchetti base;
- configura TLP;
- configura Bluetooth, fwupd, Tailscale;
- installa codec e tool hardware;
- crea lo script `check_lid.sh`;
- crea la configurazione clamshell docked;
- installa `yay` se non esiste né `yay` né `paru`;
- installa pacchetti AUR selezionati;
- non modifica automaticamente PAM.

## 25.1 Creare lo script

```bash
nano bootstrap-cachyos-l14.sh
```

Contenuto:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "==> CachyOS / ThinkPad L14 Gen 5 AMD bootstrap"

if [[ $EUID -eq 0 ]]; then
  echo "Non eseguire questo script come root. Usa un utente con sudo."
  exit 1
fi

confirm() {
  read -r -p "$1 [y/N] " ans
  [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

echo "==> Aggiornamento sistema"
sudo pacman -Syu

echo "==> Installazione pacchetti ufficiali"
sudo pacman -S --needed \
  base-devel \
  git \
  tlp \
  tlp-pd \
  tlp-rdw \
  tailscale \
  fprintd \
  telegram-desktop \
  vlc \
  kvantum \
  materia-kde \
  materia-gtk-theme \
  kvantum-theme-materia \
  papirus-icon-theme \
  fwupd \
  bluez \
  bluez-utils \
  flatpak \
  stow \
  ffmpeg \
  gst-plugins-base \
  gst-plugins-good \
  gst-plugins-bad \
  gst-plugins-ugly \
  gst-libav \
  mesa \
  vulkan-radeon \
  libva-mesa-driver \
  mesa-vdpau \
  libva-utils \
  vulkan-tools \
  docker \
  docker-compose \
  podman \
  podman-compose \
  buildah \
  skopeo \
  fuse-overlayfs \
  slirp4netns \
  passt \
  pacman-contrib

echo "==> Abilitazione servizi"
sudo systemctl enable --now tlp.service
sudo systemctl enable --now tlp-pd.service
sudo systemctl enable NetworkManager-dispatcher.service
sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket || true
sudo systemctl enable --now tailscaled.service
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now fwupd.service
sudo systemctl enable --now docker.service

echo "==> Configurazione Flatpak / Flathub"
flatpak remote-add --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo

echo "==> Creazione script controllo lid"
sudo tee /usr/local/bin/check_lid.sh >/dev/null <<'LIDCHECK'
#!/usr/bin/env bash

# Exit code:
# 0 = lid aperto/non rilevato -> consenti fingerprint
# 1 = lid chiuso -> salta fingerprint

if grep -qi "closed" /proc/acpi/button/lid/*/state 2>/dev/null; then
    exit 1
fi

exit 0
LIDCHECK

sudo chmod 755 /usr/local/bin/check_lid.sh

echo "==> Configurazione clamshell docked"
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/10-clamshell-docked.conf >/dev/null <<'LOGIND'
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
LOGIND

echo "==> Configurazione Podman rootless"
sudo touch /etc/subuid /etc/subgid
if ! grep -q "^${USER}:" /etc/subuid; then
  sudo usermod --add-subuids 100000-165535 "$USER"
fi
if ! grep -q "^${USER}:" /etc/subgid; then
  sudo usermod --add-subgids 100000-165535 "$USER"
fi
podman system migrate || true

echo "==> Verifica AUR helper"
AUR_HELPER=""

if command -v yay >/dev/null 2>&1; then
  AUR_HELPER="yay"
elif command -v paru >/dev/null 2>&1; then
  AUR_HELPER="paru"
else
  echo "==> Nessun AUR helper trovato. Installo yay."
  tmpdir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (cd "$tmpdir/yay" && makepkg -si)
  rm -rf "$tmpdir"
  AUR_HELPER="yay"
fi

echo "==> Installazione pacchetti AUR con $AUR_HELPER"
"$AUR_HELPER" -S --needed \
  ktailctl \
  visual-studio-code-bin \
  tlpui \
  zapzap \
  protonplus

echo "==> Backup file PAM"
sudo cp /etc/pam.d/system-auth "/etc/pam.d/system-auth.bak.$(date +%F-%H%M)"
sudo cp /etc/pam.d/sudo "/etc/pam.d/sudo.bak.$(date +%F-%H%M)"

echo
echo "Setup base completato."
echo
echo "Azioni manuali ancora necessarie:"
echo "1. Configura PAM seguendo la sezione 7 della guida."
echo "2. Esegui: sudo tailscale up"
echo "3. Esegui: fprintd-enroll"
echo "4. Esegui logout/login per Docker group e variabili ambiente."
echo "5. Riavvia il sistema."
```

## 25.2 Esecuzione

```bash
chmod +x bootstrap-cachyos-l14.sh
./bootstrap-cachyos-l14.sh
```

## 25.3 Dopo lo script

Eseguire:

```bash
sudo tailscale up
fprintd-enroll
```

Poi configurare PAM manualmente come nella sezione 7.

Riavviare:

```bash
sudo reboot
```

---

# 26. Verifica finale

## 26.1 Servizi

```bash
systemctl status tlp.service
systemctl status tlp-pd.service
systemctl status tailscaled.service
systemctl status bluetooth.service
systemctl status fwupd.service
```

## 26.2 TLP

```bash
sudo tlp-stat -s
sudo tlp-stat -b
```

## 26.3 Tailscale

```bash
tailscale status
tailscale ip
```

## 26.4 Fingerprint

Laptop aperto:

```bash
sudo -k
sudo ls
```

Laptop chiuso/docked:

```bash
sudo -k
sudo ls
```

## 26.5 Grafica

```bash
echo "$XDG_SESSION_TYPE"
vainfo
vulkaninfo --summary
```

## 26.6 Snapshot

Snapper:

```bash
sudo snapper list
```

Timeshift:

```bash
sudo timeshift --list
```

---

# 27. Setup finale

| Categoria | Stato |
|---|---|
| Aggiornamento sistema | configurato |
| Power management | TLP attivo |
| Soglie batteria | opzionali, configurabili |
| Docked/clamshell | configurato |
| Fingerprint docked fix | predisposto |
| KDE theme | Materia/Kvantum configurabile |
| Wayland | ottimizzato |
| Development tools | installati |
| Docker | installato |
| Podman rootless | configurato |
| Messaging apps | installate |
| Gaming tools | predisposti |
| Codec | installati |
| Firmware Lenovo | fwupd installato |
| Bluetooth | attivo |
| Tailscale | servizio attivo |
| AUR helper | yay/paru |
| Backup/snapshot | Snapper o Timeshift |
| Dotfiles | struttura pronta |
| Suspend/resume hooks | predisposti |

---

# 28. Troubleshooting rapido

## 28.1 `sudo` lento

Verificare che `check_lid.sh` funzioni:

```bash
/usr/local/bin/check_lid.sh
echo $?
```

Verificare che `pam_fprintd.so` non sia duplicato:

```bash
grep -R "pam_fprintd" /etc/pam.d/
```

## 28.2 TLP non attivo

```bash
systemctl status tlp.service
sudo tlp-stat -s
```

Verificare conflitti:

```bash
systemctl status power-profiles-daemon.service
```

## 28.3 Tailscale non si connette

```bash
systemctl status tailscaled.service
tailscale status
sudo modprobe tun
```

## 28.4 Monitor esterno non primario

```text
Impostazioni di sistema → Schermo e monitor
```

Impostare manualmente monitor primario e layout.

## 28.5 Bluetooth instabile dopo resume

Sbloccare le righe opzionali nell’hook:

```bash
sudo nano /usr/lib/systemd/system-sleep/99-thinkpad-resume.sh
```

Abilitare:

```bash
systemctl --no-block try-restart bluetooth.service
```

---

# 29. Riferimenti utili

| Componente | Tool / riferimento |
|---|---|
| Power management | `tlp`, `tlp-stat`, `tlpui` |
| Fingerprint | `fprintd`, `pam_fprintd.so` |
| Docked mode | `systemd-logind`, KDE Power Management |
| VPN mesh | `tailscale`, `ktailctl` |
| Firmware | `fwupd`, `fwupdmgr` |
| Snapshot | Snapper, Timeshift |
| Btrfs boot snapshots | grub-btrfs / limine-snapper-sync |
| Driver CachyOS | `chwd` |
| Gaming | `cachyos-gaming-meta`, `protonplus` |
| Containers | Docker, Podman |
| Dotfiles | GNU Stow |
| KDE automation | `lookandfeeltool`, `plasma-apply-colorscheme` |

---

# 30. Roadmap futura

Miglioramenti ancora possibili:

- repository Git con `README.md`, script e dotfiles;
- profili TLP separati per batteria/dock;
- configurazione KDE esportabile con Konsave;
- profilo Podman Quadlet per servizi personali;
- configurazione Tailscale SSH e ACL;
- script di restore post-install;
- backup automatico dotfiles;
- profili monitor KDE per casa/ufficio;
- integrazione con Syncthing o Nextcloud;
- hardening base con firewall e servizi minimi.
