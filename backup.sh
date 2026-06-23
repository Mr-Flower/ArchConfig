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
pacman -Qqen > "$REPO/packages/pacman.txt" && ok "packages/pacman.txt ($(wc -l < "$REPO/packages/pacman.txt"))"
pacman -Qqem > "$REPO/packages/aur.txt"    && ok "packages/aur.txt ($(wc -l < "$REPO/packages/aur.txt"))"
if command -v flatpak >/dev/null; then
    flatpak list --app --columns=application > "$REPO/packages/flatpak.txt" \
        && ok "packages/flatpak.txt ($(wc -l < "$REPO/packages/flatpak.txt"))"
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
