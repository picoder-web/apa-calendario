# 🖥️ APA Calendario - Dual-Monitor Installer

Uno script Bash interattivo per **Raspberry Pi OS** e **Ubuntu** (con ambienti X11 o Wayland/XWayland) per installare, configurare e monitorare due istanze del browser (Chromium/Chrome) a schermo intero su due monitor affiancati.

---

## 🚀 Installazione Rapida (Comando Unico)

Puoi avviare l'installer interattivo direttamente dal terminale eseguendo **uno dei seguenti comandi**:

### Con `curl`:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/picoder-web/apa-calendario/refs/heads/v2.1-rc.1/install.sh)"
```

### Con `wget`:
```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/picoder-web/apa-calendario/refs/heads/v2.1-rc.1/install.sh)"
```

> ⚠️ **Nota di sicurezza sull'utente:**  
> L'installer **non deve essere eseguito direttamente da `root`**. Eseguilo con il tuo normale utente di sistema. Se lanciato con `sudo`, lo script riconosce l'utente originale tramite `$SUDO_USER` e si riavvia automaticamente senza privilegi elevati.

---

## 📋 Requisiti e Dipendenze

Lo script verifica la presenza dei componenti necessari durante la procedura di installazione. Se utilizzi Ubuntu o Raspberry Pi OS, l'installer **tenterà di installare automaticamente tramite `apt`** le dipendenze mancanti.

### 1. Utility di Sistema (Gestione Monitor e Finestre):
* **`xrandr`** (`x11-xserver-utils`): Rileva lo stato e le geometrie delle uscite video collegate.
* **`xdotool`** (`xdotool`): Identifica e posiziona le finestre del browser sui rispettivi monitor.
* **`wmctrl`** (`wmctrl`): Gestisce la modalità Fullscreen e forza lo spostamento delle finestre se il Window Manager ignora `xdotool`.

### 2. Browser Web (almeno uno dei seguenti nel `$PATH`):
* `chromium-browser` / `chromium` *(consigliato per Raspberry Pi OS)*
* `google-chrome-stable` / `google-chrome`

---

## ⚙️ Come Funziona l'Installer (`install.sh`)

L'installer offre un menu a terminale con 5 opzioni principali:

```text
Scegli un'opzione per procedere:
 1) Installa
 2) Reinstalla / Aggiorna (aggiorna i file mantenendo i log/struttura)
 3) Reinstalla da zero (Purge completo + Nuova installazione)
 4) Disinstalla (Purge completo di tutti i file dell'applicazione)
 5) Esci
```

### Logica di Esecuzione:
1. **Rilevamento delle configurazioni precedenti:** Se il calendario è già stato installato, legge le URL e le impostazioni precedenti proponendole come valori predefiniti (*default*).
2. **Controllo Versioni:** Confronta la versione già presente con la versione `2.1` dell'installer, avvisando in caso di aggiornamento, reinstallazione o downgrade.
3. **Configurazione Interattiva:**
   * **URL Sinistra:** Pagina web da mostrare sul monitor di sinistra *(Default: `https://www.google.com`)*.
   * **URL Destra:** Pagina web da mostrare sul monitor di destra *(Default: `https://www.youtube.com`)*.
   * **Messaggio di Errore:** Testo mostrato se non vengono rilevati esattamente 2 monitor.
   * **Delay di Avvio:** Secondi di attesa dopo l'avvio del Desktop prima di lanciare i browser.
4. **Generazione Script Principale (`~/calendario/calendario.sh`):** Genera l'applicativo con gestione dei log, rotazione automatica ed esclusione del portachiavi di sistema (`--password-store=basic`).
5. **Comando Globale di Sistema (`apa-calendario`):** Crea un collegamento simbolico in `~/.local/bin/apa-calendario` (o `/usr/local/bin/apa-calendario` previa autorizzazione `sudo`) per consentire l'avvio rapido del programma digitando semplicemente `apa-calendario` da qualsiasi punto del terminale.
6. **Autostart opzionale:** Configura o rimuove il file `.desktop` in `~/.config/autostart/calendario-dual.desktop` per avviare il tool ad ogni boot del sistema.

---

## 🛠️ Funzionamento dello Script Generato (`calendario.sh`)

Una volta completata l'installazione, lo script eseguirà in automatico:

* **Gestione dei Profili:** Crea due profili isolati per Chromium (`~/chrome-dual-profili/monitor-1` e `monitor-2`) per evitare conflitti tra istanze.
* **Controllo Layout Dual-Monitor:**
  * Verifica che ci siano **esattamente 2 monitor attivi**.
  * Rileva e blocca situazioni di **mirroring** o layout non affiancati orizzontalmente.
* **Supporto Wayland / X11:** Se viene rilevata una sessione Wayland, forza l'avvio di Chromium in modalità `--ozone-platform=x11` (XWayland) per garantire il corretto posizionamento multi-schermo.
* **Supervisione in Background (Daemon):**
  * Esegue un controllo silenzioso ogni 120 secondi.
  * Se una delle due finestre si chiude o viene scollegato un monitor, chiude in modo pulito tutte le istanze del browser.
* **Gestione Log & Rotazione:**
  * Salva i log completi in `~/calendario/logs/calendario.log`.
  * Traccia gli errori critici in `~/calendario/logs/error.log`.
  * Esegue la **rotazione automatica dei log** appena superano i 5MB.

---

## 💻 Comandi Principali

### Avvio tramite Comando Personalizzato
Una volta installato, puoi avviare l'applicazione inserendo semplicemente:
```bash
apa-calendario
```

### Avvio Diretto tramite Script
In alternativa, puoi avviare lo script tramite il suo percorso originale:
```bash
~/calendario/calendario.sh
```

### Sovrascrivere temporaneamente le URL da riga di comando
Puoi passare le URL direttamente all'avvio:
```bash
apa-calendario "https://link-sinistra.it" "https://link-destra.it"
```

### Verificare la Versione Installata
```bash
bash install.sh --versione
```

---

## 🗑️ Disinstallazione e Purge

Puoi rimuovere completamente l'applicazione eseguendo l'installer e scegliendo l'opzione **4) Disinstalla**. Verranno rimossi:
* Il collegamento al comando personalizzato (`apa-calendario`)
* Il file di avvio automatico (`~/.config/autostart/calendario-dual.desktop`)
* I profili del browser (`~/chrome-dual-profili/`)
* La cartella principale dell'applicazione e dei log (`~/calendario/`)
