
# Fix fprintd Delay on Docked Laptop (Arch Linux)

Questa guida spiega come disabilitare automaticamente il timeout del lettore d'impronte digitali quando il portatile è chiuso (modalità docked/clamshell), forzando l'inserimento immediato della password.

## 1. Creazione dello Script di Controllo
Crea lo script che verifica se il coperchio (lid) è chiuso tramite ACPI.

```bash
sudo nano /usr/local/bin/check_lid.sh
```

Contenuto dello script:

```bash
#!/bin/bash
# Restituisce 1 (errore) se il lid è chiuso, 0 (successo) se è aperto
if grep -q "closed" /proc/acpi/button/lid/*/state; then
    exit 1
else
    exit 0
fi
```

Rendi lo script eseguibile:

```bash
sudo chmod +x /usr/local/bin/check_lid.sh
```

## 2. Configurazione PAM (Sudo)
Modifica il file di configurazione di sudo per inserire il controllo prima della richiesta dell'impronta.


```bash
sudo nano /etc/pam.d/sudo
```
Aggiungi la riga pam_exec.so sopra pam_fprintd.so:
```bash
Text
#%PAM-1.0
auth [success=ignore default=1] pam_exec.so quiet /usr/local/bin/check_lid.sh
auth sufficient pam_fprintd.so
auth include system-auth
```
## 3. Configurazione PAM (System Auth)
Modifica il file globale per applicare la logica al login grafico e al lock screen.
```bash
sudo nano /etc/pam.d/system-auth
```
Inserisci il controllo all'inizio della sezione auth:

``` bash
#%PAM-1.0
auth required pam_faillock.so preauth
auth [success=ignore default=1] pam_exec.so quiet /usr/local/bin/check_lid.sh
auth sufficient pam_fprintd.so
auth [success=1 default=bad] pam_unix.so try_first_pass nullok
```
## 4. Comandi di Verifica e Debug
Controllare lo stato hardware del Lid:

```bash
cat /proc/acpi/button/lid/*/state
```

Verificare il funzionamento dello script:
# Eseguilo con PC aperto e poi con PC chiuso
```bash
/usr/local/bin/check_lid.sh; echo $?
```