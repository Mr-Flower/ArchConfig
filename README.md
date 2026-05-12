# Fix fprintd Delay when Laptop is Docked (Arch Linux)

Questa guida spiega come disabilitare automaticamente la richiesta dell'impronta digitale (`fprintd`) quando il portatile è chiuso (modalità docked/clamshell) su Arch Linux.

Questo evita di dover aspettare il timeout del sensore prima di poter inserire la password.

---

# 📌 Problema

PAM (*Pluggable Authentication Modules*) tenta di usare il lettore di impronte digitali anche quando il portatile è chiuso.

Poiché il sensore non è accessibile, il sistema attende il timeout (spesso 10–30 secondi) prima di mostrare il prompt della password.

Questo comportamento può causare ritardi in:

- `sudo`
- lock screen
- login grafico
- GDM / SDDM
- sessioni docked/clamshell

---

# ✅ Soluzione

Utilizzare uno script che controlla lo stato del coperchio (*Lid*) e istruire PAM a saltare il modulo `fprintd` se il portatile risulta chiuso.

---

# 1. Creare lo Script di Controllo

Creare uno script che restituisce:

- `0` → laptop aperto → usa fingerprint
- `1` → laptop chiuso → salta fingerprint

## Creazione del file

```bash
sudo nano /usr/local/bin/check_lid.sh
```

## Contenuto dello script

```bash
#!/bin/bash

# Restituisce 1 (errore) se il lid è chiuso
# Restituisce 0 (successo) se il lid è aperto

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

# 2. Configurare PAM per sudo

Per evitare il ritardo quando si utilizza `sudo`, modificare:

```bash
sudo nano /etc/pam.d/sudo
```

## Configurazione

Aggiungere la riga `pam_exec.so` esattamente sopra `pam_fprintd.so`.

```pam
#%PAM-1.0

# Se lo script fallisce (exit 1),
# salta la riga successiva (default=1)

auth [success=ignore default=1] pam_exec.so quiet /usr/local/bin/check_lid.sh
auth sufficient pam_fprintd.so

auth include system-auth
```

---

# 3. Configurare PAM per il Sistema

Per applicare la modifica a tutto il sistema:

- login grafico
- GDM
- SDDM
- lock screen
- autenticazione PAM globale

modificare:

```bash
sudo nano /etc/pam.d/system-auth
```

## Inserire nella sezione `auth`

```pam
#%PAM-1.0

auth required pam_faillock.so preauth

# Controllo Lid per fprintd
auth [success=ignore default=1] pam_exec.so quiet /usr/local/bin/check_lid.sh
auth sufficient pam_fprintd.so

# Resto della configurazione
auth [success=1 default=bad] pam_unix.so try_first_pass nullok
```

---

# 4. Verifica

## Test con laptop aperto

Eseguire:

```bash
sudo ls
```

Dovrebbe richiedere l'impronta digitale.

---

## Test con laptop chiuso (Docked)

Eseguire:

```bash
sudo ls
```

Dovrebbe richiedere immediatamente la password senza attendere il timeout di `fprintd`.

---

# 5. Debug

Per verificare lo stato del lid in qualsiasi momento:

```bash
cat /proc/acpi/button/lid/*/state
```

## Output esempio

### Laptop aperto

```text
state:      open
```

### Laptop chiuso

```text
state:      closed
```

---

# ✅ Risultato Finale

| Scenario | Comportamento |
|---|---|
| Laptop aperto | Fingerprint attivo |
| Laptop chiuso | Password immediata |
| sudo | Nessun delay |
| Lock screen | Nessun timeout fingerprint |
| Modalità docked | Esperienza immediata |

---

# ⚠️ Note

- Testato su Arch Linux
- Compatibile con `fprintd`
- Funziona con PAM-based login manager
- Potrebbero essere necessari adattamenti su alcune distro
- Alcuni laptop usano percorsi ACPI differenti

---

# 📚 Riferimenti Utili

| Componente | Percorso |
|---|---|
| PAM config | `/etc/pam.d/` |
| Fingerprint daemon | `fprintd` |
| Stato lid ACPI | `/proc/acpi/button/lid/` |

---

# 🛠️ Possibili Miglioramenti Futuri

- Supporto multi-monitor avanzato
- Rilevamento automatico dock USB-C
- Logging con `journalctl`
- Servizio systemd dedicato
- Hook suspend/resume
- Configurazione automatica via installer script