# Fix fprintd Delay on Docked Laptop (Arch Linux)

Questa guida spiega come disabilitare automaticamente il timeout del lettore d'impronte digitali quando il portatile è chiuso (modalità docked/clamshell), forzando l'inserimento immediato della password.

---

## 📌 Obiettivo

Quando il laptop è chiuso e collegato a monitor esterni (modalità docked/clamshell), `fprintd` continua ad attendere l'impronta digitale causando un ritardo fastidioso prima della richiesta password.

Con questa configurazione:

- ✅ Laptop aperto → usa normalmente l'impronta digitale
- ✅ Laptop chiuso → salta immediatamente `fprintd`
- ✅ Login, lock screen e `sudo` diventano più rapidi in modalità docked

---

# 1. Creazione Script di Controllo Lid

Creare uno script che verifica lo stato del coperchio tramite ACPI.

## Creazione file

```bash
sudo nano /usr/local/bin/check_lid.sh
```

## Contenuto dello script

```bash
#!/bin/bash

# Se il lid è chiuso:
# exit 1 = salta fingerprint
# exit 0 = usa fingerprint

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

# 2. Configurazione PAM per sudo

Modificare:

```bash
sudo nano /etc/pam.d/sudo
```

## Configurazione

Inserire questa riga **prima** di `pam_fprintd.so`.

```pam
#%PAM-1.0

auth [success=ignore default=1] pam_exec.so quiet /usr/local/bin/check_lid.sh
auth sufficient pam_fprintd.so
auth include system-auth
```

---

# 3. Configurazione PAM Globale

Modificare:

```bash
sudo nano /etc/pam.d/system-auth
```

## Inserire nella sezione auth

```pam
#%PAM-1.0

auth required pam_faillock.so preauth

# Docked mode check
auth [success=ignore default=1] pam_exec.so quiet /usr/local/bin/check_lid.sh
auth sufficient pam_fprintd.so

auth [success=1 default=bad] pam_unix.so try_first_pass nullok
```

---

# 4. Verifica Stato Lid

Controllare se ACPI rileva correttamente il coperchio.

```bash
cat /proc/acpi/button/lid/*/state
```

Output esempio:

```text
state:      open
```

oppure

```text
state:      closed
```

---

# 5. Debug Script

Testare lo script manualmente.

```bash
/usr/local/bin/check_lid.sh
echo $?
```

## Risultati

| Codice | Significato |
|---|---|
| `0` | Lid aperto → usa fingerprint |
| `1` | Lid chiuso → salta fingerprint |

---

# 6. Risultato Finale

Dopo la configurazione:

| Scenario | Comportamento |
|---|---|
| Laptop aperto | Fingerprint attivo |
| Laptop chiuso | Password immediata |
| sudo | Nessun delay |
| Lock screen | Nessun timeout fingerprint |

---

# ⚠️ Note

- Testato su Arch Linux
- Compatibile con `fprintd`
- Funziona con PAM-based login manager
- Potrebbe richiedere adattamenti su alcune distro

---

# 📚 Riferimenti

- PAM → `/etc/pam.d/`
- Fingerprint daemon → `fprintd`
- ACPI lid state → `/proc/acpi/button/lid/`

---

# 🛠️ Possibili Miglioramenti Futuri

- Supporto multi-monitor più avanzato
- Rilevamento dock USB-C
- Logging automatico
- Script systemd integrato
- Hook suspend/resume