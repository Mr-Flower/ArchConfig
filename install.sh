#!/usr/bin/env bash
#
# install.sh — Bootstrap post-formattazione per CachyOS / ThinkPad L14 Gen5 AMD.
# Ripristina pacchetti, config di sistema, fingerprint (PAM) e theming KDE.
#
# USO:
#   ./install.sh                 esegue tutti i passi (con conferma per quelli delicati)
#   ./install.sh packages        installa solo i pacchetti
#   ./install.sh system theming  esegue solo i passi elencati
#   ASSUME_YES=1 ./install.sh     non chiede conferme (modalità non interattiva)
#
# PASSI disponibili: packages  flatpak  system  pam  theming  services
#
source "$(dirname "${BASH_SOURCE[0]}")/scripts/lib.sh"

[[ $EUID -eq 0 ]] && { err "NON eseguire come root. Lancialo da utente normale; userà sudo dove serve."; exit 1; }

# ---------------------------------------------------------------------------
# PASSO: pacchetti
# ---------------------------------------------------------------------------
step_packages() {
    info "Installazione pacchetti dai repository ufficiali"
    if [[ -s "$REPO/packages/pacman.txt" ]]; then
        sudo pacman -S --needed --noconfirm - < "$REPO/packages/pacman.txt" \
            && ok "pacchetti repo installati" \
            || warn "alcuni pacchetti repo potrebbero non essere stati installati"
    else
        warn "packages/pacman.txt vuoto o assente"
    fi

    info "Installazione pacchetti AUR"
    local helper=""
    for h in paru yay; do command -v "$h" >/dev/null 2>&1 && { helper="$h"; break; }; done
    if [[ -z "$helper" ]]; then
        warn "Nessun helper AUR (paru/yay) trovato."
        if confirm "Installo 'yay' da AUR adesso?"; then
            sudo pacman -S --needed --noconfirm base-devel git
            local tmp; tmp="$(mktemp -d)"
            git clone https://aur.archlinux.org/yay.git "$tmp/yay"
            ( cd "$tmp/yay" && makepkg -si --noconfirm )
            rm -rf "$tmp"
            helper="yay"
        fi
    fi
    if [[ -n "$helper" && -s "$REPO/packages/aur.txt" ]]; then
        "$helper" -S --needed --noconfirm - < "$REPO/packages/aur.txt" \
            && ok "pacchetti AUR installati" \
            || warn "alcuni pacchetti AUR potrebbero non essere stati installati"
    fi
}

# ---------------------------------------------------------------------------
# PASSO: flatpak (remote Flathub + app)
# ---------------------------------------------------------------------------
step_flatpak() {
    info "Installazione applicazioni Flatpak"
    if ! command -v flatpak >/dev/null 2>&1; then
        warn "flatpak non installato: esegui prima il passo 'packages'."
        return 1
    fi
    sudo flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo && ok "remote Flathub pronto"
    if [[ -s "$REPO/packages/flatpak.txt" ]]; then
        # Installa in blocco; gli ID già presenti vengono semplicemente saltati.
        # shellcheck disable=SC2046
        flatpak install -y --noninteractive flathub $(grep -vE '^\s*#|^\s*$' "$REPO/packages/flatpak.txt") \
            && ok "app Flatpak installate" \
            || warn "alcune app Flatpak potrebbero non essere state installate"
    else
        warn "packages/flatpak.txt vuoto o assente"
    fi
}

# ---------------------------------------------------------------------------
# PASSO: file di sistema (copia sicura in /etc, /usr/local/bin)
# ---------------------------------------------------------------------------
step_system() {
    info "Ripristino file di sistema"
    for rel in "${SYSTEM_FILES[@]}"; do
        local src="$REPO/system/$rel" dst="/$rel"
        [[ -e "$src" ]] || { skip "non nel repo: $rel"; continue; }
        sudo mkdir -p "$(dirname "$dst")"
        # backup del file esistente, se diverso
        if [[ -e "$dst" ]] && ! sudo cmp -s "$src" "$dst"; then
            sudo cp -a "$dst" "$dst.archconfig.bak"
            warn "backup creato: $dst.archconfig.bak"
        fi
        sudo install -m "${SYSTEM_MODES[$rel]:-644}" -o root -g root "$src" "$dst"
        ok "$dst"
    done
    info "Ricarico systemd-logind (gestione coperchio)"
    sudo systemctl kill -s HUP systemd-logind 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# PASSO: PAM fingerprint (patch IDEMPOTENTE, non sovrascrive il file)
# ---------------------------------------------------------------------------
step_pam() {
    local target="/etc/pam.d/system-auth"
    info "Configurazione fingerprint + coperchio in $target"

    if [[ ! -x /usr/local/bin/check_lid.sh ]]; then
        warn "/usr/local/bin/check_lid.sh non presente: esegui prima il passo 'system'."
        return 1
    fi
    if ! pacman -Qq fprintd >/dev/null 2>&1; then
        warn "pacchetto 'fprintd' non installato: esegui prima il passo 'packages'."
    fi

    if sudo grep -q "check_lid.sh" "$target"; then
        ok "PAM già configurato (riga check_lid.sh presente), niente da fare."
        return 0
    fi

    echo
    warn "Sto per modificare un file PAM. Una config errata può bloccare login/sudo."
    warn "Tieni aperta un'altra shell già autenticata e un TTY (Ctrl+Alt+F3) di sicurezza."
    confirm "Procedo con la modifica di $target ?" || { skip "PAM saltato su tua richiesta."; return 0; }

    sudo cp -a "$target" "$target.archconfig.bak.$(date +%F-%H%M%S)"
    ok "backup creato: $target.archconfig.bak.*"

    # Inserisce il blocco impronta subito PRIMA della prima riga 'pam_unix.so' in sezione auth.
    sudo awk '
        BEGIN { done=0 }
        /^auth/ && /pam_unix\.so/ && !done {
            print "# --- INIZIO LOGICA IMPRONTA (ArchConfig) ---"
            print "# Se check_lid.sh fallisce (coperchio chiuso) salta la riga impronta (default=1)"
            print "auth       [success=ignore default=1]  pam_exec.so quiet /usr/local/bin/check_lid.sh"
            print "auth       sufficient                  pam_fprintd.so"
            print "# --- FINE LOGICA IMPRONTA (ArchConfig) ---"
            done=1
        }
        { print }
    ' "$target" | sudo tee "$target.new" >/dev/null

    # Sanity check minimo prima di sostituire
    if sudo grep -q "pam_fprintd.so" "$target.new" && sudo grep -q "pam_unix.so" "$target.new"; then
        sudo mv "$target.new" "$target"
        ok "PAM aggiornato. TESTA SUBITO in un'altra shell: 'sudo -k && sudo ls'"
    else
        sudo rm -f "$target.new"
        err "Sanity check fallito: PAM NON modificato. File invariato."
        return 1
    fi
}

# ---------------------------------------------------------------------------
# PASSO: theming (dotfiles utente)
# ---------------------------------------------------------------------------
step_theming() {
    info "Ripristino theming KDE/GTK (dotfiles utente)"
    for rel in "${HOME_FILES[@]}"; do
        local src="$REPO/home/$rel" dst="$HOME/$rel"
        [[ -e "$src" ]] || { skip "non nel repo: $rel"; continue; }
        mkdir -p "$(dirname "$dst")"
        if [[ -e "$dst" ]] && ! cmp -s "$src" "$dst"; then
            cp -a "$dst" "$dst.archconfig.bak"
        fi
        cp -a "$src" "$dst"
        ok "$rel"
    done

    # Wallpaper del desktop (referenziati dal pannello): ricopiati dal pacchetto
    # cachyos-wallpapers, così non appesantiscono il git ed evitano icone/sfondi rotti.
    info "Ripristino wallpaper desktop da $WALLPAPER_PKG_DIR"
    if [[ -d "$WALLPAPER_PKG_DIR" ]]; then
        mkdir -p "$WALLPAPER_DEST_DIR"
        for w in "${CACHY_WALLPAPERS[@]}"; do
            if [[ -f "$WALLPAPER_PKG_DIR/$w.jpg" ]]; then
                cp -an "$WALLPAPER_PKG_DIR/$w.jpg" "$WALLPAPER_DEST_DIR/$w.jpg" && ok "wallpaper $w.jpg"
            else
                skip "non nel pacchetto: $w.jpg"
            fi
        done
    else
        warn "$WALLPAPER_PKG_DIR assente: installa prima 'cachyos-wallpapers' (passo packages)."
    fi

    # Avatar utente (immagine account) via AccountsService.
    set_avatar

    warn "Per vedere il tema applicato: esci e rientra dalla sessione (logout/login)."
}

# Imposta l'immagine dell'account utente (pig.jpg) tramite AccountsService.
# Idempotente: aggiorna/inserisce la voce Icon= nel file utente.
set_avatar() {
    local src="$REPO/home/$AVATAR_SRC_REL"
    [[ -f "$src" ]] || { skip "avatar non nel repo: $AVATAR_SRC_REL"; return; }
    info "Imposto avatar utente (potrebbe chiedere sudo)"
    local icon="/var/lib/AccountsService/icons/$USER"
    local uf="/var/lib/AccountsService/users/$USER"

    sudo install -D -m 644 "$src" "$icon" || { warn "avatar: copia in $icon fallita"; return; }
    cp -a "$src" "$HOME/.face" 2>/dev/null || true   # fallback per alcuni greeter

    if sudo test -f "$uf" && sudo grep -q '^\[User\]' "$uf"; then
        if sudo grep -q '^Icon=' "$uf"; then
            sudo sed -i "s|^Icon=.*|Icon=$icon|" "$uf"
        else
            sudo sed -i "/^\[User\]/a Icon=$icon" "$uf"
        fi
    else
        printf '[User]\nIcon=%s\nSystemAccount=false\n' "$icon" | sudo tee "$uf" >/dev/null
    fi
    ok "avatar impostato"
}

# ---------------------------------------------------------------------------
# PASSO: servizi
# ---------------------------------------------------------------------------
step_services() {
    info "Abilitazione servizi"
    local svcs=(tlp.service tlp-pd.service bluetooth.service tailscaled.service)
    for s in "${svcs[@]}"; do
        if systemctl list-unit-files "$s" >/dev/null 2>&1; then
            sudo systemctl enable --now "$s" 2>/dev/null && ok "$s" || warn "non abilitato: $s"
        else
            skip "non installato: $s"
        fi
    done
    sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------
ALL_STEPS=(packages flatpak system pam theming services)
steps=("$@")
[[ ${#steps[@]} -eq 0 ]] && steps=("${ALL_STEPS[@]}")

info "ArchConfig bootstrap — passi: ${steps[*]}"
echo
for s in "${steps[@]}"; do
    case "$s" in
        packages) step_packages ;;
        flatpak)  step_flatpak ;;
        system)   step_system ;;
        pam)      step_pam ;;
        theming)  step_theming ;;
        services) step_services ;;
        *) err "passo sconosciuto: $s (validi: ${ALL_STEPS[*]})"; exit 1 ;;
    esac
    echo
done
ok "Fatto. Riavvia o esegui logout/login per applicare tutto."
