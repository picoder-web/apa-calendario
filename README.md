# 📅 APA Calendario Dual-Monitor

Uno strumento completo ed efficace progettato per **Raspberry Pi OS** e **Ubuntu** (compatibile sia con sessioni **X11** sia con **Wayland/XWayland**) che automatizza la configurazione, l'avvio e la supervisione di due istanze indipendenti del browser a schermo intero posizionate su due monitor affiancati.

---

## 🚀 Installazione Rapida (Comando Unico)

Puoi avviare l'installer interattivo direttamente dal tuo terminale eseguendo uno dei seguenti comandi (scegli tra `curl` o `wget`):

### Con `curl`:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/picoder-web/apa-calendario/refs/heads/v2.1-rc.1/install.sh)"
```

### Con `wget`:
```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/picoder-web/apa-calendario/refs/heads/v2.1-rc.1/install.sh)"
```

> ⚠️ **Nota sull'utente:**  
> L'installer **non va eseguito con l'utente `root` o tramite `sudo`**. Esegui il comando come utente standard. Se lanciato accidentalmente tramite `sudo`, lo script individua l'utente originale tramite la variabile `$SUDO_USER` e si riavvia automaticamente mantenendo l'ambiente corretto.

---

## 📋 Requisiti e Dipendenze

Durante l'esecuzione, l'installer verifica autonomamente l'ambiente di sistema. Se utilizzi Ubuntu o Raspberry Pi OS con gestione pacchetti `apt`, **lo script proverà ad installare automaticamente i pacchetti mancanti**.

### 1. Pacchetti ed Utility di Sistema
* **`x11-xserver-utils` (`xrandr`)**: Rileva la presenza, lo stato e le geometrie pixel delle uscite video collegate.
* **`xdotool`**: Identifica e calcola la posizione delle finestre aperte dal browser.
* **`wmctrl`**: Gestisce gli attributi della finestra (es. Fullscreen) e forza il posizionamento sui display se il Window Manager non risponde a `xdotool`.

### 2. Browser Web
Lo script cerca ed utilizza uno dei seguenti browser disponibili nel `$PATH`:
* `chromium-browser` / `chromium` *(consigliato su Raspberry Pi OS)*
* `google-chrome-stable` / `google-chrome`

---

## 🛠️ Come Funziona l'Installer (`install.sh`)

L'installer offre un menu a terminale completo con 5 opzioni:

1. **Lettura Configurazione Precedente:** Rileva eventuali installazioni esistenti per mantenere e riproporre le impostazioni inserite in precedenza (URL monitor, intervalli di attesa, messaggio di errore).
2. **Gestione del Versionamento:** Rileva la versione corrente, segnalando aggiornamenti, reinstallazioni o avvisi in caso di tentativi di declassamento (*downgrade*).
3. **Configurazione Guidata Interattiva:**
   * **URL Sinistra:** URL da mostrare sul monitor principale di sinistra *(Default: `https://www.google.com`)*.
   * **URL Destra:** URL da mostrare sul monitor secondario di destra *(Default: `https://www.youtube.com`)*.
   * **Messaggio di errore custom:** Testo da mostrare a terminale qualora non vengano rilevati 2 monitor attivi.
   * **Delay di avvio:** Tempo di attesa iniziale espresso in secondi prima che vengano lanciati i browser al boot del sistema.
4. **Generazione dell'Applicativo (`~/calendario/calendario.sh`):** Scrive lo script operativo integrando opzioni per disabilitare il portachiavi (`--password-store=basic`), prevenire i popup di ripristino sessione e isolare i profili browser.
5. **Configurazione Autostart:** Crea/Aggiorna il file di avvio automatico all'accesso utente in `~/.config/autostart/calendario-dual.desktop`.

---

## 🔍 Logica di Esecuzione di `calendario.sh`

Una volta installato, lo script principale lavora nel seguente modo:

* **Profili Isolati:** Crea due cartelle profilo separate per Chromium (`~/chrome-dual-profili/monitor-1` e `monitor-2`) evitando qualsiasi conflitto di sessione o di dati.
* **Supporto Wayland:** Se l'ambiente di desktop utilizza Wayland, viene aggiunto automaticamente l'argomento `--ozone-platform=x11` garantendo il corretto funzionamento XWayland per il posizionamento tramite X11.
* **Validazione del Layout Monitor:**
  * Effettua fino a 5 tentativi di rilevamento monitor all'avvio.
  * Verifica che ci siano **esattamente 2 monitor collegati ed affiancati**.
  * Riconosce e blocca la modalità **Mirroring** (stessa coordinata $X,Y$) o la disposizione verticale non supportata.
* **Supervisione in Background (Daemon):**
  * Esegue un ciclo di controllo silenzioso in background ad intervalli regolari (120 secondi).
  * Se una delle due finestre del browser termina inaspettatamente o i monitor scendono a meno di 2, applica la chiusura automatica pulita delle risorse residua (invio di segnale `SIGTERM` ed eventualmente `SIGKILL`).
* **Gestione ed Archiviazione Log:**
  * Log di monitoraggio ed avvio: `~/calendario/logs/calendario.log`
  * Traccia dei soli errori critici: `~/calendario/logs/error.log`
  * **Rotazione automatica dei log:** Quando i file di log superano i 5MB (5120 KB), vengono automaticamente archiviati con estensione `.old` e rigenerati per prevenire l'esaurimento dello spazio su disco.

---

## 💻 Comandi Utili

### Avvio manuale dello script
```bash
~/calendario/calendario.sh
```

### Avvio con URL temporanee (override da riga di comando)
Puoi passare due URL al momento del lancio senza riconfigurare l'installer:
```bash
~/calendario/calendario.sh "https://dashboard1.example.com" "https://dashboard2.example.com"
```

### Verifica delle versioni tramite installer
```bash
bash install.sh --versione
```

---

## 🗑️ Disinstallazione e Pulizia (Purge)

Per eliminare totalmente l'applicazione ed i relativi file di configurazione dal sistema:

1. Avvia nuovamente lo script di installazione:
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/picoder-web/apa-calendario/refs/heads/v2.1-rc.1/install.sh)"
   ```
2. Seleziona l'opzione **`4) Disinstalla`**.

Verranno rimossi:
* Il file di avvio autostart (`~/.config/autostart/calendario-dual.desktop`)
* I profili dati del browser (`~/chrome-dual-profili/`)
* La directory principale dell'applicazione ed i relativi log (`~/calendario/`)
```
