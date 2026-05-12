Fix fprintd Delay when Laptop is Docked (Arch Linux)
Questa guida spiega come disabilitare automaticamente la richiesta dell'impronta digitale (fprintd) quando il portatile è chiuso (modalità docked/clamshell) su Arch Linux. Questo evita di dover aspettare il timeout del sensore prima di poter inserire la password.
Problema
PAM (Pluggable Authentication Modules) tenta di usare il lettore di impronte digitali anche quando il portatile è chiuso. Poiché il sensore non è accessibile, il sistema attende il timeout (spesso 10-30 secondi) prima di mostrare il prompt della password.
Soluzione
Utilizzare uno script che controlla lo stato del coperchio (Lid) e istruire PAM a saltare il modulo fprintd se il coperchio risulta chiuso.
1. Creare lo script di controllo
Crea uno script che restituisca un errore se il portatile è chiuso.
code
Bash
Incolla il seguente codice:
code
Bash
#!/bin/bash
# Restituisce 1 (errore) se il lid è chiuso, 0 (successo) se è aperto
if grep -q "closed" /proc/acpi/button/lid/*/state; then
    exit 1
else
    exit 0
fi
Rendi lo script eseguibile:
code
Bash
sudo chmod +x /usr/local/bin/check_lid.sh
2. Configurare PAM per Sudo
Per evitare il ritardo quando usi sudo, modifica il file /etc/pam.d/sudo.
code
Bash
sudo nano /etc/pam.d/sudo
Aggiungi la riga pam_exec.so esattamente sopra la riga di fprintd:
code
Text
#%PAM-1.0
# Se lo script fallisce (exit 1), salta la riga successiva (default=1)
auth [success=ignore default=1] pam_exec.so quiet /usr/local/bin/check_lid.sh
auth sufficient pam_fprintd.so
auth include system-auth
...
3. Configurare PAM per il Sistema (Login, GDM, SDDM)
Per applicare la modifica a tutto il sistema (login grafico, lock screen, ecc.), modifica il file system-auth.
code
Bash
sudo nano /etc/pam.d/system-auth
Inserisci il controllo all'inizio della sezione auth:
code
Text
#%PAM-1.0
auth required pam_faillock.so preauth

# Controllo Lid per fprintd
auth [success=ignore default=1] pam_exec.so quiet /usr/local/bin/check_lid.sh
auth sufficient pam_fprintd.so

# Resto della configurazione
auth [success=1 default=bad] pam_unix.so try_first_pass nullok
...
4. Verifica
Per verificare che tutto funzioni:
A PC aperto: Esegui sudo ls. Dovrebbe chiederti l'impronta.
A PC chiuso (Docked): Esegui sudo ls. Dovrebbe chiederti immediatamente la password.
Puoi debuggare lo stato del lid in ogni momento con:
code
Bash
cat /proc/acpi/button/lid/*/state
Opzione Alternativa (Input Simultaneo)
Se preferisci poter usare sia l'impronta che la password contemporaneamente senza script, puoi installare un modulo PAM modificato dall'AUR:
Installa pam-fprint-grosshack:
code
Bash
yay -S pam-fprint-grosshack
Sostituisci pam_fprintd.so con pam_fprintd_grosshack.so nei file PAM.
Questo farà apparire il prompt della password istantaneamente mentre il sensore è in ascolto.