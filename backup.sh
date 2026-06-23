#!/usr/bin/env bash
#
# backup.sh — Copia la configurazione ATTUALE del sistema dentro il repo.
# Da lanciare quando cambi qualcosa che vuoi "salvare" (tema, /etc, pacchetti).
#
#   ./backup.sh            cattura tutto
#   ./backup.sh --commit   cattura e fa un commit git automatico
#
source "$(dirname "${BASH_SOURCE[0]}")/scripts/lib.sh"

DO_COMMIT=0
[[ "${1:-}" == "--commit" ]] && DO_COMMIT=1

# Copia src -> dst creando le cartelle. Salta se la sorgente non esiste.
copy_in() {
    local src="$1" dst="$2"
    if [[ ! -e "$src" ]]; then
        skip "assente sul sistema, salto: $src"
        return
    fi
    mkdir -p "$(dirname "$dst")"
    # Prova senza privilegi (i file /etc qui sono leggibili da tutti). Usa sudo
    # SOLO se la copia normale fallisce, così non parte la richiesta impronta/sudo.
    if cp -a "$src" "$dst" 2>/dev/null; then
        ok "$src"
    elif sudo cp -a "$src" "$dst"; then
        sudo chown -R "$USER:$(id -gn)" "$dst" 2>/dev/null || true
        ok "$src (via sudo)"
    else
        err "impossibile copiare: $src"
    fi
}

info "Backup file di sistema (/etc, /usr/local/bin)"
for rel in "${SYSTEM_FILES[@]}" "${PAM_FILES[@]}"; do
    copy_in "/$rel" "$REPO/system/$rel"
done

info "Backup dotfiles utente (~)"
for rel in "${HOME_FILES[@]}"; do
    copy_in "$HOME/$rel" "$REPO/home/$rel"
done

info "Aggiorno liste pacchetti"
# Scrittura atomica (tmp + mv): se il comando fallisce il file NON viene
# troncato a zero byte, così non si perde la lista precedente.
if write_atomic "$REPO/packages/pacman.txt" pacman -Qqen; then
    ok "packages/pacman.txt ($(wc -l < "$REPO/packages/pacman.txt"))"
else
    err "aggiornamento pacman.txt fallito (lista precedente preservata)"
fi
if write_atomic "$REPO/packages/aur.txt" pacman -Qqem; then
    ok "packages/aur.txt ($(wc -l < "$REPO/packages/aur.txt"))"
else
    err "aggiornamento aur.txt fallito (lista precedente preservata)"
fi
if command -v flatpak >/dev/null; then
    if write_atomic "$REPO/packages/flatpak.txt" flatpak list --app --columns=application; then
        ok "packages/flatpak.txt ($(wc -l < "$REPO/packages/flatpak.txt"))"
    else
        err "aggiornamento flatpak.txt fallito (lista precedente preservata)"
    fi
else
    skip "flatpak non installato, salto flatpak.txt"
fi

echo
info "Stato git:"
git -C "$REPO" status -s

if [[ "$DO_COMMIT" == "1" ]]; then
    if [[ -n "$(git -C "$REPO" status -s)" ]]; then
        git -C "$REPO" add -A
        git -C "$REPO" commit -m "backup: aggiornamento config $(date +%F\ %H:%M)"
        ok "commit creato. Esegui 'git -C \"$REPO\" push' per inviarlo su GitHub."
    else
        info "Niente da committare, tutto già aggiornato."
    fi
fi
