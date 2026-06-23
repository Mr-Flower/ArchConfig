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

## ⚡ Avvio rapido automatico (TL;DR)

Questa repo ora **non è solo una guida**: contiene gli script per ripristinare tutto
da sola dopo una formattazione. La guida manuale qui sotto resta come riferimento.

### Dopo aver formattato e reinstallato CachyOS

```bash
git clone https://github.com/Mr-Flower/ArchConfig.git ~/git/ArchConfig
cd ~/git/ArchConfig
./install.sh
```

`install.sh` esegue, chiedendo conferma sui passi delicati:

| Passo | Cosa fa |
|---|---|
| `packages` | reinstalla i pacchetti repo (`packages/pacman.txt`) e AUR (`packages/aur.txt`) |
| `flatpak`  | aggiunge Flathub e installa le app Flatpak (`packages/flatpak.txt`: Bambu Studio, Gear Lever, calibre, RustDesk, ecc.) |
| `system`   | ripristina `/etc/plasmalogin.conf`, `check_lid.sh`, `tlp.conf` |
| `pam`      | aggiunge fingerprint+coperchio a `/etc/pam.d/system-auth` (patch idempotente, con backup) |
| `theming`  | ripristina look KDE/GTK/Kvantum + schema colori `MateriaDarkFlower`, **layout del pannello e applet**, **icona custom del launcher**, e ricopia i wallpaper |
| `services` | abilita `tlp`, `bluetooth`, `tailscaled` |

Puoi anche eseguire singoli passi:

```bash
./install.sh theming          # solo il tema
./install.sh packages system  # solo pacchetti + file di sistema
ASSUME_YES=1 ./install.sh      # senza conferme (sconsigliato per PAM)
```

### Salvare lo stato attuale nella repo

Quando cambi qualcosa che vuoi conservare (tema, file in `/etc`, nuovi pacchetti):

```bash
cd ~/git/ArchConfig
./backup.sh            # ricopia le config attuali dentro la repo
./backup.sh --commit   # ... e crea anche il commit git
git push               # invia su GitHub
```

### Struttura

```
install.sh        bootstrap post-formattazione
backup.sh         cattura lo stato attuale nella repo
scripts/lib.sh    helper + MANIFEST dei file tracciati (unico punto da aggiornare)
packages/         liste pacchetti pacman + AUR + flatpak (rigenerate da backup.sh)
system/           mirror di /etc e /usr/local/bin
home/             mirror dei dotfile in ~ (look KDE, pannello/applet, icona launcher)
```

> ⚠️ **Sicurezza**: PAM viene modificato con patch idempotente e backup automatico,
> mai sovrascritto alla cieca. I segreti (chiavi, stato Tailscale) sono esclusi via `.gitignore`.
> Per aggiungere un nuovo file al backup, basta aggiungerlo agli array in `scripts/lib.sh`.

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

> 🤖 **Automatizzato**: `./install.sh packages services` installa TLP e abilita i servizi; `tlp.conf` è ripristinato da `./install.sh system`.

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

> ℹ️ **Nessuna configurazione necessaria.** Su Plasma 6 / systemd recenti il
> comportamento desiderato è già il default: il sistema **non sospende** quando
> è docked o rileva un monitor esterno (`HandleLidSwitchDocked=ignore` è il
> default), e sospende normalmente quando il laptop è usato da solo. Per questo
> il repo **non** gestisce più alcun override `logind`.

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

> 🤖 **Automatizzato**: `check_lid.sh` è ripristinato da `./install.sh system`; la logica PAM da `./install.sh pam` (patch idempotente con backup).

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

> 🤖 **Automatizzato**: `./install.sh pam` inserisce le righe in `system-auth` solo se mancano, con backup automatico e sanity-check. Le istruzioni manuali qui sotto servono solo come riferimento/recovery.

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

> 🤖 **Automatizzato**: `./install.sh packages` installa tutto da `packages/pacman.txt` (repo) e `packages/aur.txt` (AUR), rigenerati da `./backup.sh`. Le liste sotto sono il riferimento "minimo".

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

> 🤖 **Automatizzato**: `./install.sh theming` ripristina il look (kdeglobals, kwinrc, Kvantum, GTK), lo schema colori `MateriaDarkFlower`, il **layout del pannello/applet** (`plasma-org.kde.plasma.desktop-appletsrc`, `plasmashellrc`), l'**icona custom del launcher** (`~/Immagini/img/start-here-cachyos-min.svg`), l'**immagine dell'account utente** (`pig.jpg`, impostata via AccountsService) e ricopia i wallpaper dal pacchetto `cachyos-wallpapers`. Dopo, fai logout/login.
>
> 🟢 **App Flatpak** (Bambu Studio, Gear Lever, calibre, RustDesk, Dolphin, RetroArch, PPSSPP): `./install.sh flatpak`. Steam e OnlyOffice sono nativi e arrivano col passo `packages`.

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

# 13. Manutenzione della repo

Questa sezione è la parte "automatica" descritta nell'[Avvio rapido](#-avvio-rapido-automatico-tldr).

## 13.1 Aggiungere un nuovo file al backup

Tutti i file tracciati sono elencati negli array dentro `scripts/lib.sh`:

- `SYSTEM_FILES` → file in `/etc`, `/usr/local/bin` (ripristinati per copia)
- `PAM_FILES` → file PAM (solo backup; ripristino tramite patch idempotente)
- `HOME_FILES` → dotfile in `~` (look KDE/GTK)

Per tracciare un nuovo file basta aggiungerlo all'array giusto e rilanciare `./backup.sh`.

## 13.2 Aggiornare lo stato dopo una modifica

```bash
./backup.sh --commit && git push
```

## 13.3 Gesti touchpad (InputActions)

Gesti personalizzati a **3 dita** su Plasma 6 Wayland, tramite il pacchetto AUR
[`inputactions-kwin`](https://github.com/taj-ny/InputActions):

| Gesto | Azione |
|---|---|
| Swipe **su** (3 dita) | Overview (`Meta+W`) |
| Swipe **giù** (3 dita) | Vista a griglia (`Meta+G`) |

I gesti **nativi a 4 dita** di KWin restano invariati (e interattivi).

- Config versionata: `home/.config/inputactions/config.yaml` (ripristinata da
  `./install.sh theming`); l'effetto è abilitato via `kwinrc` (`kwin_gesturesEnabled=true`).
- La `device_rules` alza la tolleranza d'angolo a 45° per un riconoscimento più
  affidabile delle 3 dita.
- ⚠️ `inputactions-kwin` è compilato contro l'ABI di KWin: dopo un aggiornamento
  di Plasma va **ricompilato** (`yay -S inputactions-kwin`).

## Licenza

Distribuito sotto licenza **GNU General Public License v3.0** — vedi il file [`LICENSE`](LICENSE).

## Sviluppo

Gli script bash sono lintati con [ShellCheck](https://www.shellcheck.net/):

```bash
shellcheck -x install.sh backup.sh scripts/lib.sh
```
