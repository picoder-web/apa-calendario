# APA Calendario

![Versione](https://img.shields.io/badge/versione-2.1-informational)
![Piattaforma](https://img.shields.io/badge/Piattaforma-Raspberry%20Pi%20OS%20%7C%20Ubuntu-blue)
![Shell](https://img.shields.io/badge/Shell-bash-green)

Trasforma un Raspberry Pi o un PC Ubuntu in un **display a doppio schermo**: due istanze di Chromium (o Chrome) si aprono a schermo intero su **due monitor affiancati**, ciascuna con la propria pagina web. L'applicazione può partire da sola all'accesso al desktop, si controlla in continuazione e chiude tutto in modo pulito in caso di errore.

**Versione 2.1**

## Indice

- [Caratteristiche](#caratteristiche)
- [Requisiti](#requisiti)
- [Installazione rapida](#installazione-rapida)
- [Installazione manuale](#installazione-manuale)
- [Uso da terminale](#uso-da-terminale)
- [Come funziona](#come-funziona)
- [File installati](#file-installati)
- [Configurazione](#configurazione)
- [Log e debug](#log-e-debug)
- [Aggiornamenti e versioni](#aggiornamenti-e-versioni)
- [Disinstallazione](#disinstallazione)
- [Risoluzione dei problemi](#risoluzione-dei-problemi)
- [Note su sicurezza](#note-su-sicurezza)

## Caratteristiche

- Installer interattivo con menu (installa, aggiorna, reinstalla da zero, disinstalla).
- Comando da terminale `apa-calendario` per avviare l'applicazione da qualsiasi cartella.
- Avvio automatico opzionale dopo l'accesso al desktop, con un'attesa configurabile e un terminale che mostra lo stato.
- **Due finestre a schermo intero**, una per monitor, con verifica della posizione (e correzione automatica tramite `xdotool` / `wmctrl`).
- Controllo del layout: l'applicazione parte solo con **esattamente 2 monitor attivi**, affiancati in orizzontale e non in mirroring.
- Supporto **X11** e **Wayland** (in Wayland Chromium viene avviato in modalità X11/XWayland per poter posizionare le finestre).
- Due profili del browser separati, per evitare conflitti tra le istanze.
- Supervisione silenziosa ogni 2 minuti: se una finestra si chiude o un monitor viene scollegato, tutto viene chiuso e l'errore viene registrato.
- Chiusura pulita anche con **Ctrl+C**, con segnale di terminazione o chiudendo il terminale.
- Due file di log: uno completo e uno solo con gli errori, con rotazione automatica.
- Le URL si possono sovrascrivere temporaneamente da riga di comando.
- L'installer riconosce se si tratta di una **nuova installazione o di un aggiornamento** e propone come predefiniti i valori inseriti la volta precedente.

## Requisiti

- **Sistema:** Raspberry Pi OS o Ubuntu (e derivate) con desktop grafico, sessione **X11** o **Wayland** (con XWayland).
- **Due monitor** collegati, attivi e affiancati in orizzontale (non in mirroring).
- **Browser:** almeno uno tra i seguenti nel `$PATH`:
  - `chromium-browser` / `chromium` *(consigliato per Raspberry Pi OS)*
  - `google-chrome-stable` / `google-chrome`
  - Raspberry Pi OS: `sudo apt install chromium-browser` (oppure `chromium`)
  - Ubuntu: `sudo snap install chromium`
- **Programmi di supporto**, installati automaticamente dall'installer con `apt` se mancano (può chiedere la password di `sudo`):

| Programma | Pacchetto | A cosa serve |
|---|---|---|
| `xrandr` | `x11-xserver-utils` | Rileva lo stato e le geometrie delle uscite video collegate |
| `xdotool` | `xdotool` | Identifica e posiziona le finestre del browser sui rispettivi monitor |
| `wmctrl` | `wmctrl` | Gestisce la modalità Fullscreen e forza lo spostamento delle finestre se il window manager ignora `xdotool` |

## Installazione rapida

Apri un terminale **con il tuo utente normale** (senza `sudo`) ed esegui **uno dei seguenti comandi**.

Con `curl`:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/picoder-web/apa-calendario/main/install.sh)"
```

Con `wget`:

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/picoder-web/apa-calendario/main/install.sh)"
```

L'installer scarica ed esegue lo script, poi ti guida con un menu e poche domande.

> - **Non eseguire l'installer da `root`.** I file vengono installati nella tua home e Chromium non parte se eseguito come root. Se lo lanci con `sudo`, lo script riconosce l'utente originale tramite `$SUDO_USER` e si riavvia automaticamente senza privilegi elevati.
> - Se `curl` o `wget` non sono installati: `sudo apt install curl` / `sudo apt install wget`.

### Il menu dell'installer

| Opzione | Cosa fa |
|---|---|
| **1) Installa** | Nuova installazione (si ferma se la cartella `~/calendario` esiste già) |
| **2) Reinstalla / Aggiorna** | Riscrive i file mantenendo i log e la struttura; si usa anche per cambiare URL o impostazioni |
| **3) Reinstalla da zero** | Purge completo e nuova installazione |
| **4) Disinstalla** | Purge completo di tutti i file dell'applicazione |
| **5) Esci** | Non modifica nulla |

### Le domande dell'installer

Premendo INVIO si conferma il valore tra parentesi quadre (quello della volta precedente, oppure quello predefinito).

1. **URL per il monitor di SINISTRA** (predefinito: `https://www.google.com`).
2. **URL per il monitor di DESTRA** (predefinito: `https://www.youtube.com`).
3. **Messaggio di errore** mostrato se non vengono rilevati esattamente 2 monitor (predefinito: `INSERISCI QUI IL TUO TESTO`).
4. **Secondi di attesa dopo l'avvio del desktop** prima di lanciare i browser (predefinito: `10`).
5. **Avvio automatico** all'accesso al desktop (s/n).

## Installazione manuale

```bash
git clone https://github.com/picoder-web/apa-calendario.git
cd apa-calendario
chmod +x install.sh
./install.sh
```

Anche qui l'installer va eseguito con il tuo utente, **non con `sudo`**. Se per sbaglio usi `sudo ./install.sh`, l'installer si rilancia da solo con l'utente che ha usato `sudo`.

## Uso da terminale

L'installer crea il comando **`apa-calendario`**: un collegamento simbolico in `/usr/local/bin/apa-calendario` (se `sudo` è autorizzato) oppure in `~/.local/bin/apa-calendario`. Nel secondo caso assicurati che `~/.local/bin` sia presente nel tuo `PATH` e, se necessario, **apri un nuovo terminale** prima di usare il comando.

### Avvio tramite comando personalizzato

```bash
apa-calendario
```

### Avvio diretto tramite script

In alternativa, puoi avviare lo script tramite il suo percorso originale:

```bash
~/calendario/calendario.sh
```

### Sovrascrivere temporaneamente le URL da riga di comando

Puoi passare le URL direttamente all'avvio (prima quella di sinistra, poi quella di destra):

```bash
apa-calendario "https://link-sinistra.it" "https://link-destra.it"
```

### Verificare la versione installata

```bash
bash install.sh --versione
```

- Il comando funziona **nel terminale in cui lo lanci**: lo stato viene mostrato lì e con **Ctrl+C** (o chiudendo il terminale) le finestre del browser vengono chiuse.
- Se lo script viene lanciato con `sudo`, si rilancia da solo con l'utente originale.

## Come funziona

```text
        install.sh  (menu interattivo)
              │  genera
              ▼
   ~/calendario/calendario.sh  ◀── comando globale: apa-calendario
              │  xrandr: rileva i monitor (esattamente 2, affiancati)
              ▼
 ┌──────────────────────────┬──────────────────────────┐
 │  Chromium · monitor-1    │  Chromium · monitor-2    │
 │  schermo intero          │  schermo intero          │
 │  URL SINISTRA            │  URL DESTRA              │
 └──────────────────────────┴──────────────────────────┘
              │  ogni 120 secondi
              ▼
   controllo finestre e monitor → in caso di errore chiude tutto
```

Una volta completata l'installazione, `calendario.sh` esegue in automatico questi passaggi:

1. **Attesa iniziale:** aspetta i secondi configurati dopo l'avvio del desktop (con conto alla rovescia a terminale).
2. **Ricerca del browser:** usa il primo disponibile tra `chromium-browser`, `chromium`, `google-chrome-stable`, `google-chrome` (oppure quello indicato in `BROWSER_FORZATO`).
3. **Rilevamento dei monitor:** interroga `xrandr` fino a 5 volte, con 3 secondi di pausa, in attesa di trovare esattamente 2 monitor attivi. I monitor sono ordinati per posizione orizzontale: il primo da sinistra riceve la URL di sinistra.
4. **Controllo del layout:**
   - se i monitor attivi non sono 2, mostra il **messaggio di errore** configurato e si ferma;
   - se i due monitor hanno la stessa posizione (**mirroring**) o non sono affiancati in orizzontale, si ferma con un errore.
5. **Gestione dei profili:** crea due profili isolati (`~/chrome-dual-profili/monitor-1` e `monitor-2`) per evitare conflitti tra le istanze. Il browser è avviato con `--password-store=basic`, così non viene richiesto il portachiavi di sistema.
6. **Supporto Wayland / X11:** se rileva una sessione Wayland, avvia Chromium con `--ozone-platform=x11` (XWayland) per garantire il corretto posizionamento multi-schermo.
7. **Avvio e verifica delle finestre:** apre ogni finestra a schermo intero sul proprio monitor e controlla che il centro della finestra cada dentro quel monitor. In caso contrario prova a spostarla con `xdotool` e `wmctrl`.
8. **Supervisione in background:** ogni 120 secondi controlla in silenzio che entrambe le finestre siano vive e che i monitor attivi siano ancora 2. Se una finestra si chiude o un monitor viene scollegato, chiude in modo pulito tutte le istanze del browser e registra l'errore.

La chiusura avviene prima con un segnale di terminazione; se una finestra resta attiva, viene forzata con `SIGKILL`.

## File installati

```text
~/calendario/
├── calendario.sh                  # avvio, controllo e chiusura (con la configurazione in cima)
└── logs/
    ├── calendario.log             # log completo
    └── error.log                  # solo errori
~/chrome-dual-profili/
├── monitor-1/                     # profilo di Chromium per il monitor di sinistra
└── monitor-2/                     # profilo di Chromium per il monitor di destra
/usr/local/bin/apa-calendario      # comando da terminale (collegamento), oppure:
~/.local/bin/apa-calendario        # comando da terminale (collegamento), se sudo non è autorizzato
~/.config/autostart/calendario-dual.desktop   # avvio automatico (se scelto)
```

## Configurazione

URL, messaggio di errore, attesa e avvio automatico si cambiano **rilanciando l'installer** (opzione 2). Le altre impostazioni sono variabili in cima a `~/calendario/calendario.sh`:

| Variabile | Predefinito | Significato |
|---|---|---|
| `URL_SINISTRA` | `https://www.google.com` | Pagina mostrata sul monitor di sinistra (sovrascrivibile con il primo argomento) |
| `URL_DESTRA` | `https://www.youtube.com` | Pagina mostrata sul monitor di destra (sovrascrivibile con il secondo argomento) |
| `MESSAGGIO` | `INSERISCI QUI IL TUO TESTO` | Testo mostrato se i monitor attivi non sono 2 |
| `DELAY` | `10` | Secondi di attesa prima di iniziare |
| `TENTATIVI` / `PAUSA` | `5` / `3` | Tentativi (e secondi tra l'uno e l'altro) per rilevare i monitor |
| `BROWSER_FORZATO` | vuoto | Nome o percorso di un browser specifico (vuoto = automatico) |
| `INTERVALLO_CONTROLLO` | `120` | Secondi tra un controllo completo e l'altro |
| `CHIUDI_SE_MONITOR_CAMBIANO` | `1` | Se `1`, chiude tutto quando i monitor attivi non sono più 2; con `0` registra solo un avviso |
| `MAX_LOG_KB` | `5120` | Oltre questa dimensione i log vengono ruotati (copia `.old`) |

> Le modifiche manuali a `calendario.sh` vengono **sovrascritte** da una reinstallazione: vengono mantenuti solo i valori che l'installer richiede.

## Log e debug

- **`~/calendario/logs/calendario.log`** (completo) contiene l'avvio, il sistema e la sessione rilevati, il browser usato, il rilevamento dei monitor, le verifiche di posizione delle finestre, un controllo periodico ogni 2 minuti (silenzioso a terminale) e le chiusure.
- **`~/calendario/logs/error.log`** contiene solo gli errori: monitor non validi, browser terminato subito (con le ultime righe del suo output), finestra chiusa inaspettatamente, interruzioni.
- Ogni riga ha il formato `[AAAA-MM-GG hh:mm:ss] [LIVELLO] messaggio`.
- **Rotazione automatica:** appena un log supera i 5 MB (`MAX_LOG_KB`) viene copiato in un file `.old` e ricominciato da zero.

Per seguire i log in tempo reale:

```bash
tail -f ~/calendario/logs/calendario.log
tail -f ~/calendario/logs/error.log
```

## Aggiornamenti e versioni

L'installer contiene un numero di versione (questa è la **2.1**) e lo confronta con quello già installato, mostrando:

- `NUOVA INSTALLAZIONE`;
- `AGGIORNAMENTO: da X a Y` (anche da una versione non numerata, precedente alla 2.1);
- `REINSTALLAZIONE` (stessa versione);
- un avviso se la versione installata è **più recente** di quella dell'installer, con richiesta di conferma prima di procedere.

Un suffisso come `-rc.1` conta come precedente alla versione finale (`2.2-rc.1` < `2.2`).

Per aggiornare, rilancia il [comando di installazione rapida](#installazione-rapida) e scegli l'opzione **2**: i valori che avevi inserito vengono proposti come predefiniti e ti basta premere INVIO.

## Disinstallazione

Rilancia l'installer e scegli l'opzione **4) Disinstalla**. Verranno rimossi:

- il collegamento al comando personalizzato (`apa-calendario`);
- il file di avvio automatico (`~/.config/autostart/calendario-dual.desktop`);
- i profili del browser (`~/chrome-dual-profili/`);
- la cartella principale dell'applicazione e dei log (`~/calendario/`).

Per togliere solo l'avvio automatico, elimina `~/.config/autostart/calendario-dual.desktop` oppure rilancia l'installer (opzione 2) e rispondi `n` alla domanda sull'avvio automatico.

## Risoluzione dei problemi

| Problema | Cosa fare |
|---|---|
| `apa-calendario: command not found` | Il comando è stato creato in `~/.local/bin`: assicurati che sia nel `PATH` e apri un nuovo terminale (oppure esegui `source ~/.bashrc`). In alternativa avvia `~/calendario/calendario.sh` |
| "La cartella 'calendario' esiste già" | L'opzione 1 non sovrascrive un'installazione esistente: scegli **2) Reinstalla / Aggiorna** oppure **3) Reinstalla da zero** |
| Compare il messaggio di errore configurato | Non sono stati rilevati esattamente 2 monitor attivi. Controlla i collegamenti e verifica con `xrandr --query` |
| Errore di **mirroring** | I due monitor sono duplicati: imposta nelle impostazioni dello schermo la modalità "Estendi" invece di "Duplica" |
| "I monitor non sono affiancati in orizzontale" | Disponi i monitor uno accanto all'altro (sinistra/destra) nelle impostazioni dello schermo, senza sovrapposizioni |
| Una finestra si apre sul monitor sbagliato | Controlla che `xdotool` e `wmctrl` siano installati. Su Wayland il posizionamento è più difficile: prova una sessione X11 (su Raspberry Pi OS: `sudo raspi-config` → *Advanced Options* → *Wayland* → *X11*) |
| Chromium chiede una password (portachiavi) | Il browser viene già avviato con `--password-store=basic`; se compare ancora, controlla di non aver lanciato lo script con `sudo` |
| `Running as root without --no-sandbox` | Lo script è stato eseguito come root: lancialo con il tuo utente |
| Il browser si chiude subito all'avvio | Controlla le ultime righe riportate in `~/calendario/logs/error.log` (contengono l'output del browser). Con lo snap, il profilo deve stare in una cartella non nascosta, come fa l'installer (`~/chrome-dual-profili`) |
| Tutto si chiude dopo qualche minuto | La supervisione ha rilevato una finestra chiusa o un monitor scollegato: leggi `error.log` per il motivo esatto |
| `xrandr` / `xdotool` / `wmctrl` non trovati | Installali con `sudo apt install x11-xserver-utils xdotool wmctrl` |
| Nessun browser trovato | Installa Chromium: `sudo apt install chromium-browser` (Raspberry Pi OS) oppure `sudo snap install chromium` (Ubuntu) |
| Il terminale all'avvio non si vede | Servono un terminale grafico (`gnome-terminal`, `lxterminal`, `xfce4-terminal`, `konsole` o `x-terminal-emulator`) e la sessione desktop attiva: l'avvio automatico parte all'accesso, non al boot della macchina |

## Note su sicurezza

- L'installer **non deve essere eseguito da `root`**: con `sudo` si rilancia automaticamente come utente normale.
- Prima di eseguire un comando scaricato da internet puoi leggerne il contenuto, per esempio: `curl -fsSL https://raw.githubusercontent.com/picoder-web/apa-calendario/main/install.sh | less`
- I browser vengono avviati con profili dedicati e separati da quello personale.
- Le URL e il messaggio inseriti nell'installer non possono contenere i caratteri `"` `\` `$` `` ` ``, perché verrebbero scritti nello script generato: in quel caso l'installer usa il valore precedente.
