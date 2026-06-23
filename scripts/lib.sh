#!/usr/bin/env bash
# Libreria condivisa per install.sh e backup.sh
# Contiene: helper di output, rilevamento root repo, e il MANIFEST dei file tracciati.

set -euo pipefail

# --- Output colorato -------------------------------------------------------
if [[ -t 1 ]]; then
    C_RESET=$'\e[0m'; C_BLUE=$'\e[1;34m'; C_GREEN=$'\e[1;32m'
    C_YELLOW=$'\e[1;33m'; C_RED=$'\e[1;31m'; C_DIM=$'\e[2m'
else
    C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""
fi

info()  { printf '%s==>%s %s\n'  "$C_BLUE"   "$C_RESET" "$*"; }
ok()    { printf '%s  ✔%s %s\n'  "$C_GREEN"  "$C_RESET" "$*"; }
warn()  { printf '%s  !%s %s\n'  "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()   { printf '%s  ✘%s %s\n'  "$C_RED"    "$C_RESET" "$*" >&2; }
skip()  { printf '%s  -%s %s%s%s\n' "$C_DIM" "$C_RESET" "$C_DIM" "$*" "$C_RESET"; }

# Chiede conferma (default = No). Rispetta la variabile ASSUME_YES=1.
confirm() {
    [[ "${ASSUME_YES:-0}" == "1" ]] && return 0
    local reply
    printf '%s??%s %s [s/N] ' "$C_YELLOW" "$C_RESET" "$*"
    read -r reply
    [[ "$reply" =~ ^[sSyY]$ ]]
}

# --- Helper condivisi ------------------------------------------------------

# Salva una copia .bak TIMESTAMPATA del file di destinazione, solo se esiste
# e differisce dalla sorgente. Il 3° argomento ("sudo") forza i privilegi.
#   backup_existing <dst> <src> [sudo]
backup_existing() {
    local dst="$1" src="$2" pfx="${3:-}"
    $pfx test -e "$dst" || return 0
    $pfx cmp -s "$src" "$dst" && return 0   # identico: nessun backup
    local bak="$dst.archconfig.bak.$(date +%F-%H%M%S)"
    $pfx cp -a "$dst" "$bak" && warn "backup creato: $bak"
}

# Installa una lista di pacchetti. Prima prova in blocco (veloce); se il batch
# fallisce (es. un pacchetto non più nei repo), ripiega su installazione
# singola così uno mancante non blocca tutti gli altri, e riporta i falliti.
#   install_pkglist <descrizione> <file_lista> <installer...>
install_pkglist() {
    local desc="$1" file="$2"; shift 2
    local installer=("$@")
    if [[ ! -s "$file" ]]; then
        warn "$desc: lista vuota o assente ($file)"; return 0
    fi
    local pkgs=()
    mapfile -t pkgs < <(grep -vE '^\s*#|^\s*$' "$file")
    (( ${#pkgs[@]} )) || { warn "$desc: nessun pacchetto in lista"; return 0; }

    if "${installer[@]}" "${pkgs[@]}"; then
        ok "$desc: installati (${#pkgs[@]})"
        return 0
    fi

    warn "$desc: installazione in blocco fallita, ritento singolarmente…"
    local p failed=()
    for p in "${pkgs[@]}"; do
        "${installer[@]}" "$p" >/dev/null 2>&1 || failed+=("$p")
    done
    if (( ${#failed[@]} )); then
        warn "$desc: NON installati (${#failed[@]}): ${failed[*]}"
    else
        ok "$desc: installati singolarmente"
    fi
}

# Scrive l'output di un comando in un file in modo ATOMICO (tmp + mv): se il
# comando fallisce, il file esistente NON viene troncato a zero byte.
#   write_atomic <file> <comando...>
write_atomic() {
    local file="$1"; shift
    local tmp="$file.tmp"
    if "$@" > "$tmp"; then
        mv "$tmp" "$file"
    else
        rm -f "$tmp"
        return 1
    fi
}

# --- Percorsi --------------------------------------------------------------
# REPO = cartella che contiene questo script/../  (root del repo)
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO

# ===========================================================================
# MANIFEST — l'unico posto da aggiornare per aggiungere nuovi file tracciati.
# ===========================================================================

# File di sistema gestiti per COPIA diretta (sicuri da sovrascrivere).
# Percorso relativo a / (e a system/ dentro il repo).
SYSTEM_FILES=(
    "etc/plasmalogin.conf"
    "etc/tlp.conf"
    "etc/tlp.d/10-flower.conf"
    "etc/systemd/logind.conf.d/10-clamshell-docked.conf"
    "usr/local/bin/check_lid.sh"
)

# File PAM: il ripristino NON avviene per sovrascrittura (pericoloso) bensì
# tramite patch idempotente in step_pam (sia system-auth che sudo). Vedi pam_*.
PAM_FILES=(
    "etc/pam.d/system-auth"
    "etc/pam.d/sudo"
)

# Dotfiles utente (look KDE/GTK/Kvantum + schema colori personale).
# Percorso relativo a $HOME (e a home/ dentro il repo).
HOME_FILES=(
    ".config/kdeglobals"
    ".config/kwinrc"
    ".config/plasmarc"
    ".config/kcminputrc"
    ".config/ksplashrc"
    ".config/kscreenlockerrc"
    ".config/gtkrc"
    ".config/gtk-3.0/settings.ini"
    ".config/gtk-4.0/settings.ini"
    ".config/Kvantum/kvantum.kvconfig"
    ".local/share/color-schemes/MateriaDarkFlower.colors"
    # Layout pannello: posizione elementi, applet, e icona del launcher
    ".config/plasma-org.kde.plasma.desktop-appletsrc"
    ".config/plasmashellrc"
    # Icona custom del launcher (Kickoff) in basso a sinistra
    "Immagini/img/start-here-cachyos-min.svg"
    # Immagine dell'account utente (avatar). Vedi step_theming -> AccountsService
    "Immagini/img/pig.jpg"
)

# Sorgente dell'avatar utente (impostato via AccountsService da install.sh).
AVATAR_SRC_REL="Immagini/img/pig.jpg"

# Wallpaper del desktop referenziati dal pannello: NON versionati (identici a
# quelli del pacchetto cachyos-wallpapers), vengono ricopiati da install.sh.
CACHY_WALLPAPERS=(cachy-blue cachy-dark cachy-emerald-dark cachy-purple cachy-sunset)
WALLPAPER_PKG_DIR="/usr/share/wallpapers/cachyos-wallpapers"
WALLPAPER_DEST_DIR="$HOME/Immagini/wallpapers"

# File con permessi speciali da forzare in fase di install (path -> mode).
declare -A SYSTEM_MODES=(
    ["usr/local/bin/check_lid.sh"]="755"
)
