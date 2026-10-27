#!/bin/bash
# Installer di "calendario": crea ~/calendario con script, configurazione e log
# e imposta l'avvio automatico all'accesso al desktop.
#
# Uso:  ./installa-calendario.sh [opzioni] [URL_SINISTRA] [URL_DESTRA]
#   -y, --yes        nessuna domanda: usa i valori dell'installazione precedente
#   --versione       mostra la versione installata e quella contenuta in questo installer
#   --disinstalla    rimuove solo l'avvio automatico (la cartella resta)
#
# Valori usati, in ordine di priorità:
#   1) link scritti sulla riga di comando
#   2) risposte date nella precedente installazione (lette da calendario.conf)
#   3) valori predefiniti
[ -z "$BASH_VERSION" ] && exec bash "$0" "$@"

# Va eseguito con il proprio utente (se lanciato con sudo, si rilancia come utente normale)
if [ "$(id -u)" -eq 0 ]; then
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        exec sudo -u "$SUDO_USER" env HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)" \
            bash "$(readlink -f "$0")" "$@"
    fi
    echo "Errore: esegui l'installer con il tuo utente, non come root." >&2
    exit 1
fi

VER_NUOVA="2.1"
DEST="$HOME/calendario"
CONF="$DEST/calendario.conf"
AUTOSTART="$HOME/.config/autostart/calendario.desktop"

ok()   { echo "  [OK]  $*"; }
warn() { echo "  [!!]  $*"; }

# leggi_conf CHIAVE DEFAULT: valore salvato nella configurazione precedente
leggi_conf() {
    local v=""
    [ -f "$CONF" ] && v=$( . "$CONF" >/dev/null 2>&1; printf '%s' "${!1}" )
    printf '%s' "${v:-$2}"
}

# imposta_conf CHIAVE VALORE [COMMENTO]: aggiorna la riga (o la aggiunge in fondo)
imposta_conf() {
    local k=$1 v=$2 c=$3 tmp riga nuova trovato=0
    nuova="$k=\"$v\""
    [ -n "$c" ] && nuova="$nuova   # $c"
    tmp=$(mktemp)
    while IFS= read -r riga || [ -n "$riga" ]; do
        case "$riga" in
            "$k="*) printf '%s\n' "$nuova"; trovato=1 ;;
            *)      printf '%s\n' "$riga" ;;
        esac
    done < "$CONF" > "$tmp"
    [ "$trovato" -eq 0 ] && printf '%s\n' "$nuova" >> "$tmp"
    cat "$tmp" > "$CONF"
    rm -f "$tmp"
}

# chiedi "domanda" "predefinito": INVIO conferma il valore tra parentesi quadre
chiedi() {
    local r
    read -r -p "$1 [$2]: " r
    printf '%s' "${r:-$2}"
}

# ---- Opzioni -------------------------------------------------------------
SENZA_DOMANDE=0; DISINSTALLA=0; MOSTRA_VERSIONE=0; POS=()
for a in "$@"; do
    case "$a" in
        -y|--yes)      SENZA_DOMANDE=1 ;;
        --disinstalla) DISINSTALLA=1 ;;
        --versione)    MOSTRA_VERSIONE=1 ;;
        -*)            echo "Opzione sconosciuta: $a" >&2; exit 1 ;;
        *)             POS+=("$a") ;;
    esac
done
ARG_SX="${POS[0]}"; ARG_DX="${POS[1]}"
[ -t 0 ] || SENZA_DOMANDE=1       # senza terminale interattivo non si possono fare domande

# ---- Versione già installata -------------------------------------------------
VER_ATT=""
[ -f "$DEST/calendario.sh" ] && VER_ATT=$(grep -m1 '^VERSIONE_SCRIPT=' "$DEST/calendario.sh" | cut -d'"' -f2)

if [ "$MOSTRA_VERSIONE" -eq 1 ]; then
    if [ -f "$DEST/calendario.sh" ]; then
        echo "Versione installata        : ${VER_ATT:-non numerata}"
    else
        echo "Versione installata        : nessuna (non ancora installato)"
    fi
    echo "Versione in questo installer: $VER_NUOVA"
    exit 0
fi

if [ "$DISINSTALLA" -eq 1 ]; then
    rm -f "$AUTOSTART"
    [ -f "$CONF" ] && imposta_conf AVVIO_AUTOMATICO "no" "letto dall'installer"
    echo "Avvio automatico rimosso. La cartella $DEST (script e log) è stata lasciata intatta."
    exit 0
fi

echo "=== Installazione di calendario in $DEST ==="

# ---- Tipo di installazione: nuova, aggiornamento, reinstallazione, declassamento ----
if [ ! -f "$DEST/calendario.sh" ]; then
    TIPO="nuova";  TIPO_TXT="nuova installazione, versione $VER_NUOVA"
elif [ -z "$VER_ATT" ]; then
    TIPO="aggiornamento"; TIPO_TXT="aggiornamento da una versione non numerata alla $VER_NUOVA"
elif [ "$VER_ATT" = "$VER_NUOVA" ]; then
    TIPO="uguale"; TIPO_TXT="reinstallazione della stessa versione ($VER_NUOVA)"
elif [ "$(printf '%s\n%s\n' "$VER_ATT" "$VER_NUOVA" | sort -V | head -n1)" = "$VER_ATT" ]; then
    TIPO="aggiornamento"; TIPO_TXT="aggiornamento da $VER_ATT a $VER_NUOVA"
else
    TIPO="declassamento"; TIPO_TXT="ritorno a una versione più vecchia: da $VER_ATT a $VER_NUOVA"
fi

echo
case "$TIPO" in
    nuova)         echo ">>> NUOVA INSTALLAZIONE (versione $VER_NUOVA)" ;;
    aggiornamento) echo ">>> AGGIORNAMENTO: ${TIPO_TXT#aggiornamento }" ;;
    uguale)        echo ">>> REINSTALLAZIONE: la versione $VER_NUOVA è già installata (lo script viene riscritto)" ;;
    declassamento) echo ">>> ATTENZIONE: la versione installata ($VER_ATT) è PIÙ RECENTE di quella di questo installer ($VER_NUOVA)" ;;
esac
if [ "$TIPO" = "aggiornamento" ]; then
    echo "    Novità della versione $VER_NUOVA:"
    echo "      - log completo (calendario.log) e log solo errori (errori.log) in ~/calendario"
    echo "      - le finestre si chiudono da sole in caso di errore, Ctrl+C o chiusura del terminale"
    echo "      - nessuna richiesta di password del portachiavi all'apertura del browser"
    echo "      - l'installer ricorda i valori inseriti e segnala gli aggiornamenti"
fi
if [ "$TIPO" = "declassamento" ]; then
    if [ "$SENZA_DOMANDE" -eq 0 ]; then
        RISP=$(chiedi "Installare comunque la versione più vecchia? (si/no)" "no")
        case "$RISP" in
            s|S|si|SI|Si|sì|y|Y|yes) ;;
            *) echo "Installazione annullata: non è stato modificato nulla."; exit 0 ;;
        esac
    else
        warn "Procedo comunque (modalità senza domande): la versione attuale resta in calendario.sh.bak"
    fi
fi
echo

# ---- Valori predefiniti = quelli dell'installazione precedente -----------
PREC=0; [ -f "$CONF" ] && PREC=1
[ "$PREC" -eq 1 ] && echo "Installazione precedente trovata: i suoi valori sono usati come predefiniti."

P_SX=$(leggi_conf URL_SINISTRA "https://www.google.com")
P_DX=$(leggi_conf URL_DESTRA "https://www.youtube.com")
P_MSG=$(leggi_conf MESSAGGIO "INSERISCI QUI IL TUO TESTO")
P_DELAY=$(leggi_conf DELAY 10)
P_AUTO=$(leggi_conf AVVIO_AUTOMATICO "")
if [ -z "$P_AUTO" ]; then            # configurazioni create da versioni precedenti dell'installer
    if [ "$PREC" -eq 1 ] && [ ! -f "$AUTOSTART" ]; then P_AUTO=no; else P_AUTO=si; fi
fi

R_SX="${ARG_SX:-$P_SX}"; R_DX="${ARG_DX:-$P_DX}"
R_MSG="$P_MSG"; R_DELAY="$P_DELAY"; R_AUTO="$P_AUTO"

if [ "$SENZA_DOMANDE" -eq 0 ]; then
    echo
    echo "Premi INVIO per confermare il valore tra parentesi quadre."
    [ -z "$ARG_SX" ] && R_SX=$(chiedi "Link monitor SINISTRA" "$P_SX")
    [ -z "$ARG_DX" ] && R_DX=$(chiedi "Link monitor DESTRA" "$P_DX")
    R_MSG=$(chiedi "Messaggio mostrato se i monitor non sono 2" "$P_MSG")
    R_DELAY=$(chiedi "Secondi di attesa dopo l'avvio del desktop" "$P_DELAY")
    R_AUTO=$(chiedi "Avvio automatico all'accesso al desktop (si/no)" "$P_AUTO")
    echo
fi

# ---- Controllo dei valori --------------------------------------------------
case "$R_SX$R_DX$R_MSG" in
    *\"*|*\\*|*\$*|*\`*) echo "Errore: link e messaggio non possono contenere i caratteri \" \\ \$ \`" >&2; exit 1 ;;
esac
case "$R_DELAY" in ''|*[!0-9]*) warn "Attesa non valida ('$R_DELAY'): uso $P_DELAY"; R_DELAY="$P_DELAY" ;; esac
case "$R_AUTO" in
    s|S|si|SI|Si|sì|y|Y|yes|1) R_AUTO=si ;;
    n|N|no|NO|No|0)            R_AUTO=no ;;
    *) warn "Risposta non valida per l'avvio automatico: mantengo '$P_AUTO'"; R_AUTO="$P_AUTO" ;;
esac

# 1) Cartella
mkdir -p "$DEST" && ok "Cartella pronta: $DEST" || { echo "Errore: impossibile creare $DEST" >&2; exit 1; }

# 2) Script (se esiste già, ne tiene una copia di sicurezza)
if [ -f "$DEST/calendario.sh" ]; then
    cp -f "$DEST/calendario.sh" "$DEST/calendario.sh.bak"
    ok "Versione precedente salvata in calendario.sh.bak"
fi
cat > "$DEST/calendario.sh" << 'FINE_CALENDARIO_SH'
#!/bin/bash
[ -z "$BASH_VERSION" ] && exec bash "$0" "$@"

# Se lanciato con sudo, Chromium non parte (non supporta l'esecuzione come root):
# lo script si rilancia con l'utente che ha usato sudo.
if [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    UHOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    UID_U=$(id -u "$SUDO_USER")
    XA="${XAUTHORITY:-}"
    if [ -z "$XA" ]; then
        # Ubuntu/GNOME su Wayland: file di autorizzazione di XWayland
        XA=$(ls /run/user/"$UID_U"/.mutter-Xwaylandauth.* 2>/dev/null | head -1)
        [ -z "$XA" ] && XA="$UHOME/.Xauthority"
    fi
    echo "Script lanciato con sudo: lo rilancio come utente '$SUDO_USER'..."
    exec sudo -u "$SUDO_USER" env \
        HOME="$UHOME" \
        DISPLAY="${DISPLAY:-:0}" \
        XAUTHORITY="$XA" \
        XDG_RUNTIME_DIR="/run/user/$UID_U" \
        bash "$(readlink -f "$0")" "$@"
fi

# Apre un link sul monitor di SINISTRA e uno sul monitor di DESTRA.
# Controlla che i monitor siano affiancati e che le finestre finiscano
# davvero sullo schermo giusto. Se i monitor attivi non sono esattamente 2,
# stampa il messaggio personalizzato e termina.
# Lo script RESTA ATTIVO e controlla le finestre ogni 2 minuti (in silenzio): in caso di errore, di
# interruzione (Ctrl+C, SIGTERM) o di chiusura del terminale, chiude entrambe
# le finestre del browser.
# Tutti i file (script, configurazione, log, profili del browser) stanno nella
# stessa cartella: ~/calendario
#   calendario.log : log completo (avvio, monitoraggio, controlli periodici)
#   errori.log     : solo errori e avvisi
# Uso: ./calendario.sh [URL_SINISTRA] [URL_DESTRA]   (i link si possono anche
# impostare in calendario.conf)

VERSIONE_SCRIPT="2.1"   # letta dall'installer per riconoscere gli aggiornamenti

# Cartella dello script: contiene anche configurazione, log e profili del browser
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
CONF="$DIR/calendario.conf"
LOG_COMPLETO="$DIR/calendario.log"
LOG_ERRORI="$DIR/errori.log"
PROFILI_DIR="$DIR/profili"      # cartella non nascosta: necessario per Chromium snap

# ---- VALORI PREDEFINITI (si modificano in calendario.conf) -------------
MESSAGGIO="INSERISCI QUI IL TUO TESTO"
URL_SINISTRA="https://www.google.com"
URL_DESTRA="https://www.youtube.com"
DELAY=10                        # secondi di attesa prima di iniziare
TENTATIVI=5                     # tentativi di rilevamento monitor (utile subito dopo il boot)
PAUSA=3                         # secondi tra un tentativo e l'altro
BROWSER_FORZATO=""              # opzionale: browser da usare (vuoto = automatico)
INTERVALLO_CONTROLLO=120        # secondi tra un controllo e l'altro (silenzioso)
CHIUDI_SE_MONITOR_CAMBIANO=1    # 1 = chiude tutto se i monitor attivi non sono più 2
MAX_LOG_KB=5120                 # oltre questa dimensione il log viene ruotato (.old)
# ------------------------------------------------------------------------
[ -f "$CONF" ] && . "$CONF"
# I link passati come argomenti hanno la precedenza sulla configurazione
[ -n "$1" ] && URL_SINISTRA="$1"
[ -n "$2" ] && URL_DESTRA="$2"

export DISPLAY="${DISPLAY:-:0}"

# Tipo di sessione: x11 o wayland (se la variabile manca, controlla il socket Wayland)
SESSIONE="${XDG_SESSION_TYPE:-}"
if [ -z "$SESSIONE" ]; then
    if [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${WAYLAND_DISPLAY:-wayland-0}" ]; then
        SESSIONE="wayland"
    else
        SESSIONE="x11"
    fi
fi
SISTEMA=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")
MODELLO=""
[ -r /proc/device-tree/model ] && MODELLO=$(tr -d '\0' < /proc/device-tree/model)

# ---- Log ---------------------------------------------------------------
# _scrivi LIVELLO testo: scrive nel log completo; ERRORE, AVVISO e DETTAGLIO
# (dettagli di un errore) vengono scritti anche in errori.log
_scrivi() {
    local liv=$1 riga
    shift
    riga="$(date '+%F %T') [$liv] $*"
    echo "$riga" >> "$LOG_COMPLETO" 2>/dev/null
    case "$liv" in
        ERRORE|AVVISO|DETTAGLIO) echo "$riga" >> "$LOG_ERRORI" 2>/dev/null ;;
    esac
}
# log: terminale + log. I messaggi che iniziano per "ERRORE:" o "ATTENZIONE:"
# finiscono anche in errori.log
log() {
    local liv=INFO msg="$*"
    case "$msg" in
        ERRORE:*)      liv=ERRORE; msg="${msg#ERRORE: }" ;;
        ATTENZIONE:*)  liv=AVVISO; msg="${msg#ATTENZIONE: }" ;;
    esac
    echo "[$(date +%H:%M:%S)] $*"
    _scrivi "$liv" "$msg"
}
info()     { echo "           $*"; _scrivi INFO "$*"; }       # dettaglio (solo log completo)
info_e()   { echo "           $*"; _scrivi DETTAGLIO "$*"; }  # dettaglio di un errore (anche errori.log)
solo_log() { _scrivi INFO "$*"; }                              # solo log completo, nessun output a terminale

# Ruota i log troppo grandi (tiene una copia .old)
ruota_log() {
    local f
    for f in "$LOG_COMPLETO" "$LOG_ERRORI"; do
        if [ -f "$f" ] && [ "$(stat -c %s "$f" 2>/dev/null || echo 0)" -gt $((MAX_LOG_KB * 1024)) ]; then
            mv -f "$f" "$f.old"
        fi
    done
}

attendi_chiusura() {
    echo
    read -rp "Premi INVIO per chiudere questo terminale..." _
}

# Il centro della finestra $1 è dentro il monitor $2 (indice 0 o 1)?
# Imposta CX e CY. Ritorna 0 se dentro, 1 se fuori, 2 se non legge la geometria.
centro_in_monitor() {
    local wid=$1 i=$2 out wx wy ww wh
    out=$(xdotool getwindowgeometry --shell "$wid" 2>/dev/null) || return 2
    wx=$(echo "$out" | sed -n 's/^X=//p');      wy=$(echo "$out" | sed -n 's/^Y=//p')
    ww=$(echo "$out" | sed -n 's/^WIDTH=//p');  wh=$(echo "$out" | sed -n 's/^HEIGHT=//p')
    [ -z "$wx" ] || [ -z "$ww" ] && return 2
    CX=$((wx + ww / 2)); CY=$((wy + wh / 2))
    if [ "$CX" -ge "${MX[$i]}" ] && [ "$CX" -lt $((MX[i] + MW[i])) ] &&
       [ "$CY" -ge "${MY[$i]}" ] && [ "$CY" -lt $((MY[i] + MH[i])) ]; then
        return 0
    fi
    return 1
}

# Elenco degli ID delle finestre Chromium/Chrome attualmente visibili
finestre_chromium() {
    xdotool search --onlyvisible --class "chrom" 2>/dev/null | sort -u
}

# Verifica (ed eventualmente corregge) la posizione della finestra del monitor $1.
# $2 = elenco delle finestre Chromium presenti PRIMA dell'avvio: la finestra
# cercata è quella nuova (la più grande), senza dipendere da nome o classe.
verifica_finestra() {
    local i=$1 prima=$2 wid="" n id out w h area best=0
    if ! command -v xdotool >/dev/null; then
        if [ -z "$AVVISO_XDOTOOL" ]; then
            info "Verifica posizione saltata: installa xdotool e wmctrl (sudo apt install xdotool wmctrl)"
            AVVISO_XDOTOOL=1
        fi
        return
    fi
    for ((n = 1; n <= 10; n++)); do
        best=0; wid=""
        for id in $(finestre_chromium); do
            grep -qx "$id" <<< "$prima" && continue
            out=$(xdotool getwindowgeometry --shell "$id" 2>/dev/null)
            w=$(echo "$out" | sed -n 's/^WIDTH=//p'); h=$(echo "$out" | sed -n 's/^HEIGHT=//p')
            [ -z "$w" ] && continue
            area=$((w * h))
            if [ "$area" -gt "$best" ]; then best=$area; wid=$id; fi
        done
        [ -n "$wid" ] && break
        sleep 1
    done
    if [ -z "$wid" ]; then
        log "ATTENZIONE: nessuna nuova finestra Chromium trovata, posizione non verificabile."
        info_e "Finestre visibili (ID, classe, titolo):"
        for id in $(xdotool search --onlyvisible --name "." 2>/dev/null | head -15); do
            info_e "  $id | $(xdotool getwindowclassname "$id" 2>/dev/null) | $(xdotool getwindowname "$id" 2>/dev/null)"
        done
        return
    fi
    centro_in_monitor "$wid" "$i"
    case $? in
        0) log "Posizione OK: la finestra è sul monitor ${ETICHETTE[$i]} (centro $CX,$CY)."; return ;;
        2) log "ATTENZIONE: impossibile leggere la geometria della finestra."; return ;;
    esac

    log "ATTENZIONE: la finestra NON è sul monitor ${ETICHETTE[$i]} (centro $CX,$CY)."
    if ! command -v wmctrl >/dev/null; then
        info_e "Per correggere automaticamente installa wmctrl (sudo apt install wmctrl)."
        return
    fi
    info "Provo a spostarla in ${MX[$i]},${MY[$i]}..."
    wmctrl -i -r "$wid" -b remove,fullscreen
    xdotool windowmove "$wid" "${MX[$i]}" "${MY[$i]}"
    sleep 1
    wmctrl -i -r "$wid" -b add,fullscreen
    sleep 1
    if centro_in_monitor "$wid" "$i"; then
        log "Correzione riuscita: ora la finestra è sul monitor ${ETICHETTE[$i]} (centro $CX,$CY)."
    else
        log "ATTENZIONE: correzione NON riuscita (centro $CX,$CY): il window manager ignora lo spostamento."
    fi
}

PIDS=()
OUTS=()
AVVISO_XDOTOOL=""
CHIUSURA_FATTA=0
MOTIVO_USCITA=""

# Numero di monitor attivi (con geometria assegnata)
conta_monitor_attivi() {
    xrandr --query 2>/dev/null | grep ' connected' | grep -cE '[0-9]+x[0-9]+\+[0-9]+\+[0-9]+'
}

# L'istanza $1 (0 o 1) del browser è ancora in esecuzione?
istanza_viva() {
    local i=$1
    { [ -n "${PIDS[$i]}" ] && kill -0 "${PIDS[$i]}" 2>/dev/null; } ||
        pgrep -f "$PROFILI_DIR/monitor-$((i + 1))" >/dev/null 2>&1
}

# Chiude entrambe le finestre del browser (prima con SIGTERM, poi con SIGKILL se serve)
chiudi_browser() {
    [ "$CHIUSURA_FATTA" -eq 1 ] && return
    CHIUSURA_FATTA=1
    [ "${#PIDS[@]}" -eq 0 ] && return
    log "Chiusura delle finestre del browser in corso..."
    local i n vivo
    for i in "${!PIDS[@]}"; do
        kill -TERM -- "-${PIDS[$i]}" 2>/dev/null       # gruppo di processi creato da setsid
        pkill -TERM -f "$PROFILI_DIR/monitor-$((i + 1))" 2>/dev/null
    done
    for ((n = 0; n < 10; n++)); do
        vivo=0
        for i in "${!PIDS[@]}"; do istanza_viva "$i" && vivo=1; done
        [ "$vivo" -eq 0 ] && break
        sleep 0.5
    done
    for i in "${!PIDS[@]}"; do
        if istanza_viva "$i"; then
            log "ATTENZIONE: finestra $((i + 1)) ancora attiva, forzo la chiusura (SIGKILL)."
            kill -KILL -- "-${PIDS[$i]}" 2>/dev/null
            pkill -KILL -f "$PROFILI_DIR/monitor-$((i + 1))" 2>/dev/null
        fi
    done
    log "Finestre chiuse."
}

# Errore durante l'esecuzione: chiude tutto, mostra il messaggio e attende prima di uscire
errore_fatale() {
    echo
    log "ERRORE: $*"
    chiudi_browser
    attendi_chiusura
    exit 1
}

# Chiamata a ogni uscita dallo script (normale, errore o segnale)
uscita_script() {
    local rc=$?
    if [ "${#PIDS[@]}" -gt 0 ] && [ "$CHIUSURA_FATTA" -eq 0 ]; then
        echo
        log "${MOTIVO_USCITA:-Script terminato (codice $rc)}: chiudo le finestre."
        chiudi_browser
    fi
    [ "${#OUTS[@]}" -gt 0 ] && rm -f "${OUTS[@]}" 2>/dev/null
    _scrivi INFO "===== Script terminato (codice $rc) ====="
}
trap 'MOTIVO_USCITA="Interruzione da tastiera (Ctrl+C)"; exit 130' INT
trap 'MOTIVO_USCITA="Segnale di terminazione (SIGTERM)"; exit 143' TERM
trap 'MOTIVO_USCITA="Terminale chiuso (SIGHUP)"; exit 129' HUP
trap uscita_script EXIT

mkdir -p "$DIR"
ruota_log
_scrivi INFO "===== Avvio script v$VERSIONE_SCRIPT (PID $$, utente $(id -un), cartella $DIR) ====="
echo "=== Avvio automatico doppio schermo ==="

# 0) Informazioni essenziali
log "Sistema: ${SISTEMA:-sconosciuto}${MODELLO:+ ($MODELLO)} | utente: $(id -un) | sessione: $SESSIONE"
log "Link  SINISTRA: $URL_SINISTRA  |  DESTRA: $URL_DESTRA"
if [ "$(id -u)" -eq 0 ]; then
    log "ATTENZIONE: script eseguito come root: Chromium non partirà senza --no-sandbox. Usa il tuo utente."
fi
OZONE_ARGS=()
if [ "$SESSIONE" = "wayland" ]; then
    # Su Wayland le app non possono scegliere la posizione delle finestre:
    # Chromium viene avviato in modalità X11 (XWayland), dove il posizionamento funziona.
    OZONE_ARGS=(--ozone-platform=x11)
    log "Sessione Wayland: Chromium sarà avviato in modalità X11 (XWayland)."
fi

# 1) Attesa iniziale con conto alla rovescia
for ((s = DELAY; s > 0; s--)); do
    printf "\r[%s] Avvio tra %2d secondi...   " "$(date +%H:%M:%S)" "$s"
    sleep 1
done
[ "$DELAY" -gt 0 ] && echo

# 2) Ricerca del browser
if [ -n "$BROWSER_FORZATO" ]; then
    BROWSER=$(command -v "$BROWSER_FORZATO")
else
    BROWSER=$(command -v chromium-browser || command -v chromium || command -v google-chrome-stable || command -v google-chrome)
fi
if [ -z "$BROWSER" ]; then
    log "ERRORE: nessun browser Chromium/Chrome trovato nel PATH."
    info_e "Raspberry Pi OS: sudo apt install chromium-browser (o chromium) | Ubuntu: sudo snap install chromium"
    attendi_chiusura
    exit 1
fi
VERSIONE=$("$BROWSER" --version 2>/dev/null | head -1)
log "Browser: $BROWSER (${VERSIONE:-versione sconosciuta})"

# 3) Rilevamento monitor (con più tentativi, i monitor possono comparire in ritardo)
if ! command -v xrandr >/dev/null; then
    log "ERRORE: il comando xrandr non è installato (sudo apt install x11-xserver-utils)."
    attendi_chiusura
    exit 1
fi

MONITORS=()
NOMI=()
for ((t = 1; t <= TENTATIVI; t++)); do
    RAW=$(xrandr --query 2>&1)
    if [ $? -ne 0 ]; then
        log "ERRORE: xrandr ha restituito un errore:"
        echo "$RAW" | while IFS= read -r riga; do info_e "$riga"; done
    fi

    # Elenco "X nome geometria" dei soli monitor attivi, ordinati da sinistra a destra
    ELENCO=$(echo "$RAW" | grep ' connected' | while read -r nome _; do
        geom=$(echo "$RAW" | grep "^$nome " | grep -oE '[0-9]+x[0-9]+\+[0-9]+\+[0-9]+' | head -1)
        [ -n "$geom" ] && echo "$(echo "$geom" | cut -d+ -f2) $nome $geom"
    done | sort -n)

    MONITORS=()
    NOMI=()
    while read -r _x nome geom; do
        [ -z "$nome" ] && continue
        NOMI+=("$nome")
        MONITORS+=("$geom")
    done <<< "$ELENCO"

    solo_log "Rilevamento monitor, tentativo $t/$TENTATIVI: ${#MONITORS[@]} attivi (${NOMI[*]})"
    [ "${#MONITORS[@]}" -eq 2 ] && break
    if [ "$t" -lt "$TENTATIVI" ]; then
        log "Monitor attivi: ${#MONITORS[@]} (ne servono 2), riprovo tra $PAUSA secondi ($t/$TENTATIVI)..."
        sleep "$PAUSA"
    fi
done

# 4) Verifica: servono esattamente 2 monitor
if [ "${#MONITORS[@]}" -ne 2 ]; then
    log "ERRORE: monitor attivi = ${#MONITORS[@]} (ne servono 2): le finestre non vengono avviate."
    _scrivi DETTAGLIO "Messaggio mostrato a schermo: $MESSAGGIO"
    echo
    echo "$MESSAGGIO"
    echo "$MESSAGGIO" > /dev/tty1 2>/dev/null
    attendi_chiusura
    exit 1
fi

# 5) Controllo del posizionamento: i monitor devono essere affiancati
RE='^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$'
MW=(); MH=(); MX=(); MY=()
for i in 0 1; do
    if [[ "${MONITORS[$i]}" =~ $RE ]]; then
        MW[$i]=${BASH_REMATCH[1]}; MH[$i]=${BASH_REMATCH[2]}
        MX[$i]=${BASH_REMATCH[3]}; MY[$i]=${BASH_REMATCH[4]}
    else
        log "ERRORE: geometria non interpretabile: '${MONITORS[$i]}'"
        attendi_chiusura
        exit 1
    fi
done

ETICHETTE=("SINISTRA" "DESTRA")
log "Monitor  SINISTRA: ${NOMI[0]} ${MW[0]}x${MH[0]} (${MX[0]},${MY[0]})  |  DESTRA: ${NOMI[1]} ${MW[1]}x${MH[1]} (${MX[1]},${MY[1]})"

if [ "${MX[0]}" -eq "${MX[1]}" ] && [ "${MY[0]}" -eq "${MY[1]}" ]; then
    log "ERRORE: i due monitor hanno la stessa posizione (${MX[0]},${MY[0]}): sono in MIRRORING/duplicati."
    info_e "Imposta la modalità 'estesa', ad esempio: xrandr --output ${NOMI[1]} --right-of ${NOMI[0]} --auto"
    attendi_chiusura
    exit 1
elif [ $((MX[0] + MW[0])) -gt "${MX[1]}" ]; then
    log "ERRORE: i monitor non sono affiancati in orizzontale (si sovrappongono o sono uno sopra l'altro)."
    info_e "Imposta il secondo a destra del primo, ad esempio: xrandr --output ${NOMI[1]} --right-of ${NOMI[0]} --auto"
    attendi_chiusura
    exit 1
fi

SPAZIO=$((MX[1] - MX[0] - MW[0]))
[ "$SPAZIO" -gt 0 ] && info "Nota: tra i due monitor c'è uno spazio vuoto di $SPAZIO pixel."
[ "${MY[0]}" -ne "${MY[1]}" ] && info "Nota: i monitor non sono allineati in alto (Y: ${MY[0]} e ${MY[1]})."

# 6) Avvio delle due finestre
URLS=("$URL_SINISTRA" "$URL_DESTRA")
mkdir -p "$PROFILI_DIR"

for i in 0 1; do
    PROFILO="$PROFILI_DIR/monitor-$((i + 1))"
    OUT=$(mktemp "${TMPDIR:-/tmp}/calendario-browser-$((i + 1)).XXXXXX")
    OUTS[$i]=$OUT
    CLASSE="chrome-dual-$((i + 1))"

    log "Avvio ${ETICHETTE[$i]} su ${NOMI[$i]} (${MX[$i]},${MY[$i]}): ${URLS[$i]}"

    # Finestre Chromium già presenti (per riconoscere quella nuova dopo il lancio)
    PRIMA=""
    command -v xdotool >/dev/null && PRIMA=$(finestre_chromium)

    # setsid: ogni browser ha il proprio gruppo di processi, chiudibile in blocco
    setsid "$BROWSER" \
        --user-data-dir="$PROFILO" \
        --class="$CLASSE" \
        "${OZONE_ARGS[@]}" \
        --window-position="${MX[$i]},${MY[$i]}" \
        --start-fullscreen \
        --no-first-run \
        --noerrdialogs \
        --disable-infobars \
        --password-store=basic \
        --disable-session-crashed-bubble \
        --hide-crash-restore-bubble \
        --new-window "${URLS[$i]}" >>"$OUT" 2>&1 &
    PID=$!
    PIDS[$i]=$PID
    solo_log "Monitor ${ETICHETTE[$i]}: browser avviato (PID $PID, profilo $PROFILO)"

    sleep 4

    if kill -0 "$PID" 2>/dev/null; then
        verifica_finestra "$i" "$PRIMA"
    else
        log "ERRORE: il browser del monitor ${ETICHETTE[$i]} è terminato subito."
        info_e "Ultime righe dell'output del browser:"
        tail -n 10 "$OUT" 2>/dev/null | while IFS= read -r riga; do info_e "$riga"; done
        errore_fatale "Avvio fallito sul monitor ${ETICHETTE[$i]}: chiudo anche l'altra finestra."
    fi
done

# 7) Supervisione silenziosa: lo script resta attivo e non stampa nulla finché va tutto bene
echo
if [ "$INTERVALLO_CONTROLLO" -ge 60 ]; then ETICHETTA_INTERVALLO="$((INTERVALLO_CONTROLLO / 60)) min"; else ETICHETTA_INTERVALLO="${INTERVALLO_CONTROLLO} s"; fi
log "Tutto avviato. Controllo le finestre ogni $ETICHETTA_INTERVALLO (in silenzio). Ctrl+C o chiusura del terminale: chiude le finestre."

CONTROLLO=0
while true; do
    sleep "$INTERVALLO_CONTROLLO" & wait $!
    CONTROLLO=$((CONTROLLO + 1))

    for i in 0 1; do
        istanza_viva "$i" ||
            errore_fatale "La finestra del monitor ${ETICHETTE[$i]} non è più attiva (chiusa o andata in errore): chiudo anche l'altra."
    done

    # Controllo dei monitor, ripetuto per qualche secondo per evitare falsi allarmi momentanei
    for ((k = 1; k <= 3; k++)); do
        N=$(conta_monitor_attivi)
        [ "$N" -eq 2 ] && break
        [ "$k" -lt 3 ] && sleep "$PAUSA"
    done
    if [ "$N" -ne 2 ]; then
        [ "$CHIUDI_SE_MONITOR_CAMBIANO" -eq 1 ] &&
            errore_fatale "I monitor attivi non sono più 2 (ora $N): chiudo le finestre."
        log "ATTENZIONE: monitor attivi = $N (ne servono 2), chiusura automatica disattivata."
    fi

    solo_log "Controllo n. $CONTROLLO: 2 finestre attive (PID ${PIDS[0]} e ${PIDS[1]}), monitor attivi: $N"

    # Tiene sotto controllo la dimensione dell'output temporaneo dei browser
    for f in "${OUTS[@]}"; do
        [ -n "$(find "$f" -size +1M 2>/dev/null)" ] && : > "$f"
    done
done
FINE_CALENDARIO_SH
chmod +x "$DEST/calendario.sh" && ok "Script installato: $DEST/calendario.sh"

# 3) Configurazione: creata se manca, poi aggiornata con i valori scelti
#    (le altre voci che hai modificato a mano restano come sono)
if [ ! -f "$CONF" ]; then
    cat > "$CONF" << 'FINE_CONF'
# Configurazione di calendario.sh (letta a ogni avvio)
TENTATIVI=5                     # tentativi di rilevamento monitor
PAUSA=3                         # secondi tra un tentativo e l'altro
BROWSER_FORZATO=""              # vuoto = automatico
INTERVALLO_CONTROLLO=120        # secondi tra un controllo e l'altro
CHIUDI_SE_MONITOR_CAMBIANO=1    # 1 = chiude tutto se i monitor non sono più 2
MAX_LOG_KB=5120                 # oltre questa dimensione i log vengono ruotati
FINE_CONF
    ok "Configurazione creata: $CONF"
else
    ok "Configurazione esistente aggiornata: $CONF"
fi
imposta_conf URL_SINISTRA "$R_SX" "link mostrato sul monitor di sinistra"
imposta_conf URL_DESTRA "$R_DX" "link mostrato sul monitor di destra"
imposta_conf MESSAGGIO "$R_MSG" "mostrato se i monitor non sono 2"
imposta_conf DELAY "$R_DELAY" "secondi di attesa prima di iniziare"
imposta_conf AVVIO_AUTOMATICO "$R_AUTO" "letto dall'installer (si/no)"
ok "Link sinistra : $R_SX"
ok "Link destra   : $R_DX"
ok "Attesa avvio  : $R_DELAY secondi"

# 4) File di log
touch "$DEST/calendario.log" "$DEST/errori.log" && ok "Log pronti: calendario.log (completo) ed errori.log (solo errori)"
echo "$(date '+%F %T') [INFO] Installer: $TIPO_TXT" >> "$DEST/calendario.log"

# 5) Programmi necessari
MANCANTI=""
for coppia in xrandr:x11-xserver-utils xdotool:xdotool wmctrl:wmctrl; do
    command -v "${coppia%%:*}" >/dev/null || MANCANTI="$MANCANTI ${coppia##*:}"
done
if [ -n "$MANCANTI" ]; then
    echo "  ...   Mancano:$MANCANTI"
    if command -v apt-get >/dev/null; then
        echo "        Installo con apt (potrebbe chiedere la password di sudo)..."
        if sudo apt-get install -y $MANCANTI >/dev/null 2>&1; then
            ok "Installati:$MANCANTI"
        else
            warn "Installazione non riuscita. Fallo a mano: sudo apt install$MANCANTI"
        fi
    else
        warn "Installa a mano:$MANCANTI"
    fi
else
    ok "Programmi necessari già presenti (xrandr, xdotool, wmctrl)"
fi

BROWSER=$(command -v chromium-browser || command -v chromium || command -v google-chrome-stable || command -v google-chrome)
if [ -n "$BROWSER" ]; then
    ok "Browser trovato: $BROWSER"
else
    warn "Nessun browser Chromium/Chrome trovato. Raspberry Pi OS: sudo apt install chromium-browser | Ubuntu: sudo snap install chromium"
fi

# 6) Avvio automatico all'accesso al desktop (in un terminale che mostra lo stato)
if [ "$R_AUTO" = "si" ]; then
    if command -v gnome-terminal >/dev/null; then      TERM_CMD="gnome-terminal --title=\"Calendario\" --"
    elif command -v lxterminal >/dev/null; then        TERM_CMD="lxterminal --title=\"Calendario\" -e"
    elif command -v xfce4-terminal >/dev/null; then    TERM_CMD="xfce4-terminal --title=\"Calendario\" -x"
    elif command -v konsole >/dev/null; then           TERM_CMD="konsole -e"
    elif command -v x-terminal-emulator >/dev/null; then TERM_CMD="x-terminal-emulator -e"
    elif command -v xterm >/dev/null; then             TERM_CMD="xterm -T \"Calendario\" -e"
    else TERM_CMD=""
    fi
    if [ -n "$TERM_CMD" ]; then
        mkdir -p "$HOME/.config/autostart"
        cat > "$AUTOSTART" << DESKTOP
[Desktop Entry]
Type=Application
Name=Calendario
Exec=$TERM_CMD "$DEST/calendario.sh"
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP
        ok "Avvio automatico impostato (terminale: ${TERM_CMD%% *})"
    else
        warn "Nessun terminale grafico trovato: avvio automatico NON impostato."
    fi
else
    rm -f "$AUTOSTART"
    ok "Avvio automatico disattivato (come richiesto)"
fi

echo
echo "=== Installazione completata: $TIPO_TXT ==="
echo "  Avvio manuale : $DEST/calendario.sh"
echo "  Configurazione: $CONF"
echo "  Log completo  : $DEST/calendario.log"
echo "  Solo errori   : $DEST/errori.log"
echo "  Rilanciando questo installer, i valori di adesso saranno i predefiniti."
echo "  Versione      : ./installa-calendario.sh --versione"
echo "  Disinstallare : ./installa-calendario.sh --disinstalla"
