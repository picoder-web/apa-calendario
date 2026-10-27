#!/bin/bash
[ -z "$BASH_VERSION" ] && exec bash "$0" "$@"
# ==============================================================================
# Installer Interattivo per Calendario Dual-Monitor su Raspberry Pi / Ubuntu
# ==============================================================================
VERSIONE_INSTALLER="2.1"

# Va eseguito con il proprio utente: se lanciato con sudo, si rilancia come utente normale
if [ "$(id -u)" -eq 0 ]; then
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        exec sudo -u "$SUDO_USER" env HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)" \
            bash "$(readlink -f "$0")" "$@"
    fi
    echo "Errore: esegui l'installer con il tuo utente, non come root." >&2
    exit 1
fi

# Percorsi principali
USER_HOME="$HOME"
TARGET_DIR="$USER_HOME/calendario"
LOG_DIR="$TARGET_DIR/logs"
SCRIPT_NAME="calendario.sh"
SCRIPT_PATH="$TARGET_DIR/$SCRIPT_NAME"
PROFILI_DIR="$USER_HOME/chrome-dual-profili"
AUTOSTART_DIR="$USER_HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/calendario-dual.desktop"
CUSTOM_CMD="apa-calendario"
SYMLINK_USER="$USER_HOME/.local/bin/$CUSTOM_CMD"
SYMLINK_SYS="/usr/local/bin/$CUSTOM_CMD"

# Definizione dei Colori per Output Terminale
CLR_RESET="\e[0m"
CLR_TIME="\e[1;36m"     # Ciano Bold
CLR_INFO="\e[1;32m"     # Verde Bold
CLR_WARN="\e[1;33m"     # Giallo Bold
CLR_ERR="\e[1;31m"      # Rosso Bold
CLR_HEAD="\e[1;35m"     # Magenta Bold

# Valori predefiniti (usati solo se non esiste una installazione precedente)
DEF_SX="https://www.google.com"
DEF_DX="https://www.youtube.com"
DEF_MSG="INSERISCI QUI IL TUO TESTO"
DEF_DELAY="10"

mostra_header() {
    clear
    echo -e "${CLR_HEAD}============================================================${CLR_RESET}"
    echo -e "${CLR_HEAD}       INSTALLER INTERATTIVO: CALENDARIO DUAL-MONITOR       ${CLR_RESET}"
    echo -e "${CLR_HEAD}                       versione $VERSIONE_INSTALLER                         ${CLR_RESET}"
    echo -e "${CLR_HEAD}============================================================${CLR_RESET}"
    echo
}

leggi_var() {   # leggi_var NOME
    [ -f "$SCRIPT_PATH" ] || return 0
    case "$1" in
        URL_SINISTRA|URL_DESTRA)
            sed -n "s/^$1=\"\${[12]:-\(.*\)}\".*/\1/p" "$SCRIPT_PATH" | head -n1 ;;
        MESSAGGIO|VERSIONE_SCRIPT)
            sed -n "s/^$1=\"\([^\"]*\)\".*/\1/p" "$SCRIPT_PATH" | head -n1 ;;
        DELAY)
            sed -n 's/^DELAY=\([0-9][0-9]*\).*/\1/p' "$SCRIPT_PATH" | head -n1 ;;
    esac
}

carica_precedenti() {
    VER_ATT=$(leggi_var VERSIONE_SCRIPT)
    P_SX=$(leggi_var URL_SINISTRA);  P_SX="${P_SX:-$DEF_SX}"
    P_DX=$(leggi_var URL_DESTRA);    P_DX="${P_DX:-$DEF_DX}"
    P_MSG=$(leggi_var MESSAGGIO);    P_MSG="${P_MSG:-$DEF_MSG}"
    P_DELAY=$(leggi_var DELAY);      P_DELAY="${P_DELAY:-$DEF_DELAY}"
    if [ -f "$SCRIPT_PATH" ] && [ ! -f "$AUTOSTART_FILE" ]; then P_AUTO="n"; else P_AUTO="s"; fi
}

versione_minore() {
    local til='~' a b
    a="${1//-/$til}"; b="${2//-/$til}"
    [ "$a" != "$b" ] && [ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -n1)" = "$a" ]
}

classifica_versione() {
    if [ ! -f "$SCRIPT_PATH" ]; then
        TIPO="nuova";         TIPO_TXT="nuova installazione, versione $VERSIONE_INSTALLER"
    elif [ -z "$VER_ATT" ]; then
        TIPO="aggiornamento"; TIPO_TXT="aggiornamento da una versione non numerata (precedente alla 2.1) alla $VERSIONE_INSTALLER"
    elif [ "$VER_ATT" = "$VERSIONE_INSTALLER" ]; then
        TIPO="uguale";        TIPO_TXT="reinstallazione della stessa versione ($VERSIONE_INSTALLER)"
    elif versione_minore "$VER_ATT" "$VERSIONE_INSTALLER"; then
        TIPO="aggiornamento"; TIPO_TXT="aggiornamento da $VER_ATT a $VERSIONE_INSTALLER"
    else
        TIPO="declassamento"; TIPO_TXT="ritorno a una versione più vecchia: da $VER_ATT a $VERSIONE_INSTALLER"
    fi
}

mostra_stato_versione() {
    case "$TIPO" in
        nuova)         echo -e "Stato: ${CLR_WARN}nessuna installazione trovata${CLR_RESET} (questo installer contiene la versione $VERSIONE_INSTALLER)" ;;
        uguale)        echo -e "Stato: installata la versione ${CLR_INFO}$VER_ATT${CLR_RESET}, uguale a quella di questo installer" ;;
        aggiornamento) echo -e "Stato: installata ${CLR_WARN}${VER_ATT:-una versione non numerata}${CLR_RESET} -> ${CLR_INFO}AGGIORNAMENTO DISPONIBILE${CLR_RESET} alla $VERSIONE_INSTALLER" ;;
        declassamento) echo -e "Stato: installata la $VER_ATT, ${CLR_ERR}più recente${CLR_RESET} di questo installer ($VERSIONE_INSTALLER)" ;;
    esac
    echo
}

mostra_banner_tipo() {
    case "$TIPO" in
        nuova)         echo -e "${CLR_INFO}>>> NUOVA INSTALLAZIONE (versione $VERSIONE_INSTALLER)${CLR_RESET}" ;;
        aggiornamento) echo -e "${CLR_INFO}>>> AGGIORNAMENTO: ${TIPO_TXT#aggiornamento }${CLR_RESET}" ;;
        uguale)        echo -e "${CLR_WARN}>>> REINSTALLAZIONE: la versione $VERSIONE_INSTALLER è già installata (lo script viene riscritto)${CLR_RESET}" ;;
        declassamento) echo -e "${CLR_ERR}>>> ATTENZIONE: la versione installata ($VER_ATT) è PIÙ RECENTE di quella di questo installer ($VERSIONE_INSTALLER)${CLR_RESET}" ;;
    esac
    echo
}

conferma_declassamento() {
    [ "$TIPO" = "declassamento" ] || return 0
    read -rp "Installare comunque la versione più vecchia? (s/n) [default: n]: " RISP_DECL
    [[ "$RISP_DECL" =~ ^[Ss]$ ]] && return 0
    echo "Installazione annullata: non è stato modificato nulla."
    return 1
}

funzione_purge() {
    echo -e "${CLR_WARN}--> [PURGE] RIMOZIONE DI TUTTI I FILE DELL'APPLICAZIONE...${CLR_RESET}"

    if [ -f "$AUTOSTART_FILE" ]; then
        rm -f "$AUTOSTART_FILE"
        echo -e "    - Rimosso file di avvio automatico ($AUTOSTART_FILE)."
    fi

    if [ -L "$SYMLINK_SYS" ] || [ -f "$SYMLINK_SYS" ]; then
        sudo rm -f "$SYMLINK_SYS" 2>/dev/null && echo -e "    - Rimosso comando globale ($SYMLINK_SYS)."
    fi
    if [ -L "$SYMLINK_USER" ] || [ -f "$SYMLINK_USER" ]; then
        rm -f "$SYMLINK_USER" && echo -e "    - Rimosso comando utente ($SYMLINK_USER)."
    fi

    if [ -d "$PROFILI_DIR" ]; then
        rm -rf "$PROFILI_DIR"
        echo -e "    - Rimossa cartella profili Chromium (~/chrome-dual-profili)."
    fi

    if [ -d "$TARGET_DIR" ]; then
        rm -rf "$TARGET_DIR"
        echo -e "    - Rimossa la cartella principale dell'applicazione ($TARGET_DIR)."
    fi

    echo -e "${CLR_INFO}--> Purge completato con successo.${CLR_RESET}"
    echo
}

valida_testo() {
    case "$1" in *\"*|*\\*|*\$*|*\`*) return 1 ;; esac
    return 0
}

chiedi_config() {
    echo -e "${CLR_HEAD}------------------------------------------------------------${CLR_RESET}"
    echo -e "${CLR_HEAD}CONFIGURAZIONE (INVIO = conferma il valore tra parentesi)${CLR_RESET}"
    echo -e "${CLR_HEAD}------------------------------------------------------------${CLR_RESET}"
    read -rp "Inserisci l'URL per il monitor di SINISTRA [default: $P_SX]: " INPUT_URL_SIN
    URL_SINISTRA="${INPUT_URL_SIN:-$P_SX}"

    read -rp "Inserisci l'URL per il monitor di DESTRA   [default: $P_DX]: " INPUT_URL_DES
    URL_DESTRA="${INPUT_URL_DES:-$P_DX}"

    read -rp "Messaggio mostrato se i monitor non sono 2 [default: $P_MSG]: " INPUT_MSG
    MESSAGGIO_TXT="${INPUT_MSG:-$P_MSG}"

    read -rp "Secondi di attesa dopo l'avvio del desktop [default: $P_DELAY]: " INPUT_DELAY
    DELAY_SEC="${INPUT_DELAY:-$P_DELAY}"

    valida_testo "$URL_SINISTRA" || { echo -e "${CLR_WARN}Link sinistra con caratteri non consentiti: uso '$P_SX'${CLR_RESET}"; URL_SINISTRA="$P_SX"; }
    valida_testo "$URL_DESTRA"   || { echo -e "${CLR_WARN}Link destra con caratteri non consentiti: uso '$P_DX'${CLR_RESET}"; URL_DESTRA="$P_DX"; }
    valida_testo "$MESSAGGIO_TXT" || { echo -e "${CLR_WARN}Messaggio con caratteri non consentiti: uso '$P_MSG'${CLR_RESET}"; MESSAGGIO_TXT="$P_MSG"; }
    case "$DELAY_SEC" in ''|*[!0-9]*) echo -e "${CLR_WARN}Attesa non valida ('$DELAY_SEC'): uso $P_DELAY${CLR_RESET}"; DELAY_SEC="$P_DELAY" ;; esac
    echo
}

crea_comando_personalizzato() {
    echo -e "${CLR_INFO}--> Configurazione del comando personalizzato '$CUSTOM_CMD'...${CLR_RESET}"
    if sudo -n true 2>/dev/null || sudo ln -sf "$SCRIPT_PATH" "$SYMLINK_SYS" 2>/dev/null; then
        echo -e "${CLR_INFO}--> Comando '$CUSTOM_CMD' creato in $SYMLINK_SYS${CLR_RESET}"
    else
        mkdir -p "$USER_HOME/.local/bin"
        ln -sf "$SCRIPT_PATH" "$SYMLINK_USER"
        echo -e "${CLR_INFO}--> Comando '$CUSTOM_CMD' creato in $SYMLINK_USER${CLR_RESET}"
        if [[ ":$PATH:" != *":$USER_HOME/.local/bin:"* ]]; then
            echo -e "${CLR_WARN}    Nota: Assicurati che ~/.local/bin sia presente nel tuo PATH.${CLR_RESET}"
        fi
    fi
    echo
}

genera_script() {
    echo -e "${CLR_INFO}--> Generazione della struttura e dello script principale ($SCRIPT_NAME)...${CLR_RESET}"
    mkdir -p "$LOG_DIR"

    {
        cat << EOF
#!/bin/bash
[ -z "\$BASH_VERSION" ] && exec bash "\$0" "\$@"

# ---- CONFIGURAZIONE (scritta da install.sh v$VERSIONE_INSTALLER) ------------------
VERSIONE_SCRIPT="$VERSIONE_INSTALLER"
MESSAGGIO="$MESSAGGIO_TXT"
URL_SINISTRA="\${1:-$URL_SINISTRA}"
URL_DESTRA="\${2:-$URL_DESTRA}"
DELAY=$DELAY_SEC
TENTATIVI=5
PAUSA=3
BROWSER_FORZATO=""
INTERVALLO_CONTROLLO=120
CHIUDI_SE_MONITOR_CAMBIANO=1
MAX_LOG_KB=5120
# ------------------------------------------------------------------------
EOF
        cat << 'FINE_SCRIPT'

if [ "$(id -u)" -eq 0 ] && [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    UHOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    UID_U=$(id -u "$SUDO_USER")
    XA="${XAUTHORITY:-}"
    if [ -z "$XA" ]; then
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

DIR_APP="$HOME/calendario"
DIR_LOGS="$DIR_APP/logs"
LOG_FULL="$DIR_LOGS/calendario.log"
LOG_ERR="$DIR_LOGS/error.log"

mkdir -p "$DIR_LOGS"

C_RST="\e[0m"
C_TM="\e[1;36m"
C_INF="\e[1;32m"
C_WRN="\e[1;33m"
C_ERR="\e[1;31m"

export DISPLAY="${DISPLAY:-:0}"

pulisci_ansi() {
    echo -e "$1" | sed -r "s/\x1B\[[0-9;]*[a-zA-Z]//g"
}

log() {
    local stamp="${C_TM}[$(date '+%Y-%m-%d %H:%M:%S')]${C_RST}"
    local msg="$stamp ${C_INF}[INFO]${C_RST} $*"
    echo -e "$msg"
    pulisci_ansi "$msg" >> "$LOG_FULL"
}

log_warn() {
    local stamp="${C_TM}[$(date '+%Y-%m-%d %H:%M:%S')]${C_RST}"
    local msg="$stamp ${C_WRN}[WARN]${C_RST} $*"
    echo -e "$msg"
    pulisci_ansi "$msg" >> "$LOG_FULL"
}

log_error() {
    local stamp="${C_TM}[$(date '+%Y-%m-%d %H:%M:%S')]${C_RST}"
    local msg="$stamp ${C_ERR}[ERROR]${C_RST} $*"
    echo -e "$msg" >&2
    pulisci_ansi "$msg" >> "$LOG_FULL"
    pulisci_ansi "$msg" >> "$LOG_ERR"
}

info() {
    local msg="           $*"
    echo -e "$msg"
    pulisci_ansi "$msg" >> "$LOG_FULL"
}

info_err() {
    printf '           %s\n' "$*" >&2
    printf '           %s\n' "$*" >> "$LOG_FULL"
    printf '           %s\n' "$*" >> "$LOG_ERR"
}

log_file() {
    printf '[%s] [INFO] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FULL"
}

ruota_log() {
    local f
    for f in "$LOG_FULL" "$LOG_ERR"; do
        if [ -f "$f" ] && [ "$(stat -c %s "$f" 2>/dev/null || echo 0)" -gt $((MAX_LOG_KB * 1024)) ]; then
            cp -f "$f" "$f.old" && : > "$f"
        fi
    done
}

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

attendi_chiusura() {
    echo
    read -rp "Premi INVIO per chiudere questo terminale..." _
}

centro_in_monitor() {
    local wid=$1 i=$2 out wx wy ww wh
    out=$(xdotool getwindowgeometry --shell "$wid" 2>/dev/null) || return 2
    wx=$(echo "$out" | sed -n 's/^X=//p');     wy=$(echo "$out" | sed -n 's/^Y=//p')
    ww=$(echo "$out" | sed -n 's/^WIDTH=//p'); wh=$(echo "$out" | sed -n 's/^HEIGHT=//p')
    [ -z "$wx" ] || [ -z "$ww" ] && return 2
    CX=$((wx + ww / 2)); CY=$((wy + wh / 2))
    if [ "$CX" -ge "${MX[$i]}" ] && [ "$CX" -lt $((MX[i] + MW[i])) ] &&
       [ "$CY" -ge "${MY[$i]}" ] && [ "$CY" -lt $((MY[i] + MH[i])) ]; then
        return 0
    fi
    return 1
}

finestre_chromium() {
    xdotool search --onlyvisible --class "chrom" 2>/dev/null | sort -u
}

verifica_finestra() {
    local i=$1 prima=$2 wid="" n id out w h area best=0
    if ! command -v xdotool >/dev/null; then
        if [ -z "$AVVISO_XDOTOOL" ]; then
            info "Verifica posizione saltata: installa xdotool e wmctrl"
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
        info "Nessuna nuova finestra Chromium trovata: posizione non verificabile."
        return
    fi
    centro_in_monitor "$wid" "$i"
    case $? in
        0) log "Posizione OK: finestra sul monitor ${ETICHETTE[$i]} (centro $CX,$CY)."; return ;;
        2) info "Impossibile leggere la geometria della finestra."; return ;;
    esac

    log_warn "La finestra NON è sul monitor ${ETICHETTE[$i]} (centro $CX,$CY)."
    if ! command -v wmctrl >/dev/null; then
        info "Per correggere automaticamente installa wmctrl (sudo apt install wmctrl)."
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
        log_error "Correzione NON riuscita (centro $CX,$CY). Il window manager ignora lo spostamento."
    fi
}

PIDS=()
OUTS=()
AVVISO_XDOTOOL=""
CHIUSURA_FATTA=0
MOTIVO_USCITA=""

conta_monitor_attivi() {
    xrandr --query 2>/dev/null | grep ' connected' | grep -cE '[0-9]+x[0-9]+\+[0-9]+\+[0-9]+'
}

istanza_viva() {
    local i=$1
    { [ -n "${PIDS[$i]}" ] && kill -0 "${PIDS[$i]}" 2>/dev/null; } ||
        pgrep -f "chrome-dual-profili/monitor-$((i + 1))" >/dev/null 2>&1
}

chiudi_browser() {
    [ "$CHIUSURA_FATTA" -eq 1 ] && return
    CHIUSURA_FATTA=1
    [ "${#PIDS[@]}" -eq 0 ] && return
    log "Chiusura delle finestre del browser in corso..."
    local i n vivo
    for i in "${!PIDS[@]}"; do
        kill -TERM -- "-${PIDS[$i]}" 2>/dev/null
        pkill -TERM -f "chrome-dual-profili/monitor-$((i + 1))" 2>/dev/null
    done
    for ((n = 0; n < 10; n++)); do
        vivo=0
        for i in "${!PIDS[@]}"; do istanza_viva "$i" && vivo=1; done
        [ "$vivo" -eq 0 ] && break
        sleep 0.5
    done
    for i in "${!PIDS[@]}"; do
        if istanza_viva "$i"; then
            info "Finestra $((i + 1)) ancora attiva: forzo la chiusura (SIGKILL)."
            kill -KILL -- "-${PIDS[$i]}" 2>/dev/null
            pkill -KILL -f "chrome-dual-profili/monitor-$((i + 1))" 2>/dev/null
        fi
    done
    log "Finestre chiuse."
}

errore_fatale() {
    echo
    log_error "$*"
    chiudi_browser
    attendi_chiusura
    exit 1
}

uscita_script() {
    local rc=$?
    if [ "${#PIDS[@]}" -gt 0 ] && [ "$CHIUSURA_FATTA" -eq 0 ]; then
        echo
        log_error "${MOTIVO_USCITA:-Script terminato inaspettatamente (codice $rc)}: chiudo le finestre."
        chiudi_browser
    elif [ -n "$MOTIVO_USCITA" ]; then
        log_error "$MOTIVO_USCITA"
    fi
    [ "${#OUTS[@]}" -gt 0 ] && rm -f "${OUTS[@]}" 2>/dev/null
    log_file "===== Script terminato (codice $rc) ====="
}

trap 'MOTIVO_USCITA="Interruzione da tastiera (Ctrl+C)"; exit 130' INT
trap 'MOTIVO_USCITA="Segnale di terminazione (SIGTERM)"; exit 143' TERM
trap 'MOTIVO_USCITA="Terminale chiuso (SIGHUP)"; exit 129' HUP
trap uscita_script EXIT

ruota_log
log_file "===== Avvio script v$VERSIONE_SCRIPT (PID $$, utente $(id -un)) ====="
log "=== Avvio automatico doppio schermo (v$VERSIONE_SCRIPT) ==="
log "Sistema: ${SISTEMA:-sconosciuto}${MODELLO:+ ($MODELLO)} | utente: $(id -un) | sessione: $SESSIONE"
log "Link SINISTRA: $URL_SINISTRA | DESTRA: $URL_DESTRA"

if [ "$(id -u)" -eq 0 ]; then
    log_warn "ATTENZIONE: script eseguito come root: Chromium non partirà senza --no-sandbox."
fi

OZONE_ARGS=()
if [ "$SESSIONE" = "wayland" ]; then
    OZONE_ARGS=(--ozone-platform=x11)
    log "Sessione Wayland: Chromium sarà avviato in modalità X11 (XWayland)."
fi

for ((s = DELAY; s > 0; s--)); do
    printf "\r\e[1;36m[%s]\e[0m \e[1;33m[WAIT]\e[0m Avvio tra %2d secondi...   " "$(date +%H:%M:%S)" "$s"
    sleep 1
done
[ "$DELAY" -gt 0 ] && echo

if [ -n "$BROWSER_FORZATO" ]; then
    BROWSER=$(command -v "$BROWSER_FORZATO")
else
    BROWSER=$(command -v chromium-browser || command -v chromium || command -v google-chrome-stable || command -v google-chrome)
fi

if [ -z "$BROWSER" ]; then
    log_error "Nessun browser Chromium/Chrome trovato nel PATH."
    attendi_chiusura
    exit 1
fi

VERSIONE=$("$BROWSER" --version 2>/dev/null | head -1)
log "Browser: $BROWSER (${VERSIONE:-versione sconosciuta})"

if ! command -v xrandr >/dev/null; then
    log_error "Il comando xrandr non è installato."
    attendi_chiusura
    exit 1
fi

MONITORS=()
NOMI=()
for ((t = 1; t <= TENTATIVI; t++)); do
    RAW=$(xrandr --query 2>&1)
    if [ $? -ne 0 ]; then
        log_error "xrandr ha restituito un errore: $RAW"
    fi

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

    log_file "Rilevamento monitor, tentativo $t/$TENTATIVI: ${#MONITORS[@]} attivi (${NOMI[*]})"
    [ "${#MONITORS[@]}" -eq 2 ] && break
    if [ "$t" -lt "$TENTATIVI" ]; then
        log_warn "Monitor attivi: ${#MONITORS[@]} (ne servono 2), riprovo tra $PAUSA secondi ($t/$TENTATIVI)..."
        sleep "$PAUSA"
    fi
done

if [ "${#MONITORS[@]}" -ne 2 ]; then
    log_error "Condizione NON soddisfatta: monitor attivi = ${#MONITORS[@]} (ne servono 2)."
    echo "$MESSAGGIO"
    attendi_chiusura
    exit 1
fi

RE='^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$'
MW=(); MH=(); MX=(); MY=()
for i in 0 1; do
    if [[ "${MONITORS[$i]}" =~ $RE ]]; then
        MW[$i]=${BASH_REMATCH[1]}; MH[$i]=${BASH_REMATCH[2]}
        MX[$i]=${BASH_REMATCH[3]}; MY[$i]=${BASH_REMATCH[4]}
    else
        log_error "Geometria non interpretabile: '${MONITORS[$i]}'"
        attendi_chiusura
        exit 1
    fi
done

ETICHETTE=("SINISTRA" "DESTRA")
log "Monitor SINISTRA: ${NOMI[0]} ${MW[0]}x${MH[0]} (${MX[0]},${MY[0]}) | DESTRA: ${NOMI[1]} ${MW[1]}x${MH[1]} (${MX[1]},${MY[1]})"

if [ "${MX[0]}" -eq "${MX[1]}" ] && [ "${MY[0]}" -eq "${MY[1]}" ]; then
    log_error "I due monitor hanno la stessa posizione (${MX[0]},${MY[0]}): sono in MIRRORING."
    attendi_chiusura
    exit 1
elif [ $((MX[0] + MW[0])) -gt "${MX[1]}" ]; then
    log_error "I monitor non sono affiancati in orizzontale."
    attendi_chiusura
    exit 1
fi

URLS=("$URL_SINISTRA" "$URL_DESTRA")

for i in 0 1; do
    PROFILO="$HOME/chrome-dual-profili/monitor-$((i + 1))"
    CLASSE="chrome-dual-$((i + 1))"
    OUT=$(mktemp "${TMPDIR:-/tmp}/calendario-browser-$((i + 1)).XXXXXX")
    OUTS[$i]=$OUT

    log "Avvio ${ETICHETTE[$i]} su ${NOMI[$i]} (${MX[$i]},${MY[$i]}): ${URLS[$i]}"

    PRIMA=""
    command -v xdotool >/dev/null && PRIMA=$(finestre_chromium)

    setsid "$BROWSER" \
        --user-data-dir="$PROFILO" \
        --class="$CLASSE" \
        "${OZONE_ARGS[@]}" \
        --window-position="${MX[$i]},${MY[$i]}" \
        --start-fullscreen \
        --no-first-run \
        --noerrdialogs \
        --disable-infobars \
        --disable-session-crashed-bubble \
        --hide-crash-restore-bubble \
        --password-store=basic \
        --new-window "${URLS[$i]}" >>"$OUT" 2>&1 &
    PID=$!
    PIDS[$i]=$PID
    log_file "Monitor ${ETICHETTE[$i]}: browser avviato (PID $PID, profilo $PROFILO)"

    sleep 4

    if kill -0 "$PID" 2>/dev/null; then
        verifica_finestra "$i" "$PRIMA"
    else
        log_error "Il browser del monitor ${ETICHETTE[$i]} è terminato subito."
        info_err "Ultime righe dell'output del browser:"
        tail -n 10 "$OUT" 2>/dev/null | while IFS= read -r riga; do info_err "$riga"; done
        errore_fatale "Avvio fallito sul monitor ${ETICHETTE[$i]}."
    fi
done

if [ "$INTERVALLO_CONTROLLO" -ge 60 ]; then
    ETICHETTA_INTERVALLO="$((INTERVALLO_CONTROLLO / 60)) min"
else
    ETICHETTA_INTERVALLO="${INTERVALLO_CONTROLLO} s"
fi
log "Tutto avviato. Supervisione attiva: controllo ogni $ETICHETTA_INTERVALLO in silenzio (dettagli in $LOG_FULL)."

CONTROLLO=0
while true; do
    sleep "$INTERVALLO_CONTROLLO" & wait $!
    CONTROLLO=$((CONTROLLO + 1))

    for i in 0 1; do
        istanza_viva "$i" || errore_fatale "La finestra del monitor ${ETICHETTE[$i]} si è chiusa inaspettatamente."
    done

    for ((k = 1; k <= 3; k++)); do
        N=$(conta_monitor_attivi)
        [ "$N" -eq 2 ] && break
        [ "$k" -lt 3 ] && sleep "$PAUSA"
    done
    if [ "$N" -ne 2 ]; then
        [ "$CHIUDI_SE_MONITOR_CAMBIANO" -eq 1 ] && errore_fatale "I monitor attivi non sono più 2 (ora $N)."
        log_warn "Monitor attivi = $N (ne servono 2), chiusura automatica disattivata."
    fi

    log_file "Controllo n. $CONTROLLO: 2 finestre attive (PID ${PIDS[0]} e ${PIDS[1]}), monitor attivi: $N"

    ruota_log
    for f in "${OUTS[@]}"; do
        [ -n "$(find "$f" -size +1M 2>/dev/null)" ] && : > "$f"
    done
done
FINE_SCRIPT
    } > "$SCRIPT_PATH"

    chmod +x "$SCRIPT_PATH"
    echo -e "${CLR_INFO}--> Script principale creato in $SCRIPT_PATH${CLR_RESET}"
}

controlla_dipendenze() {
    echo -e "${CLR_HEAD}------------------------------------------------------------${CLR_RESET}"
    echo -e "${CLR_HEAD}CONTROLLO PROGRAMMI NECESSARI${CLR_RESET}"
    echo -e "${CLR_HEAD}------------------------------------------------------------${CLR_RESET}"
    local mancanti="" coppia
    for coppia in xrandr:x11-xserver-utils xdotool:xdotool wmctrl:wmctrl; do
        command -v "${coppia%%:*}" >/dev/null || mancanti="$mancanti ${coppia##*:}"
    done
    if [ -n "$mancanti" ]; then
        echo -e "${CLR_WARN}--> Mancano:$mancanti${CLR_RESET}"
        if command -v apt-get >/dev/null; then
            echo "    Installo con apt (potrebbe chiedere la password di sudo)..."
            if sudo apt-get install -y $mancanti >/dev/null 2>&1; then
                echo -e "${CLR_INFO}--> Installati:$mancanti${CLR_RESET}"
            else
                echo -e "${CLR_ERR}--> Installazione non riuscita. Fallo a mano: sudo apt install$mancanti${CLR_RESET}"
            fi
        else
            echo -e "${CLR_ERR}--> Installa a mano:$mancanti${CLR_RESET}"
        fi
    else
        echo -e "${CLR_INFO}--> Programmi necessari già presenti (xrandr, xdotool, wmctrl).${CLR_RESET}"
    fi

    local browser
    browser=$(command -v chromium-browser || command -v chromium || command -v google-chrome-stable || command -v google-chrome)
    if [ -n "$browser" ]; then
        echo -e "${CLR_INFO}--> Browser trovato: $browser${CLR_RESET}"
    else
        echo -e "${CLR_ERR}--> Nessun browser Chromium/Chrome trovato. Raspberry Pi OS: sudo apt install chromium-browser | Ubuntu: sudo snap install chromium${CLR_RESET}"
    fi
    echo
}

comando_terminale() {
    if   command -v gnome-terminal    >/dev/null; then echo "gnome-terminal --title=\"Calendario\" --"
    elif command -v lxterminal        >/dev/null; then echo "lxterminal --title=\"Calendario\" -e"
    elif command -v xfce4-terminal    >/dev/null; then echo "xfce4-terminal --title=\"Calendario\" -x"
    elif command -v konsole           >/dev/null; then echo "konsole -e"
    else echo "x-terminal-emulator -e"
    fi
}

gestisci_autostart() {
    echo -e "${CLR_HEAD}------------------------------------------------------------${CLR_RESET}"
    echo -e "${CLR_HEAD}CONFIGURAZIONE AVVIO AUTOMATICO (AUTOSTART)${CLR_RESET}"
    echo -e "${CLR_HEAD}------------------------------------------------------------${CLR_RESET}"
    read -rp "Vuoi eseguire l'applicazione automaticamente ad ogni avvio del sistema? (s/n) [default: $P_AUTO]: " RISP_AUTO
    RISP_AUTO="${RISP_AUTO:-$P_AUTO}"

    if [[ "$RISP_AUTO" =~ ^[Ss]$ ]]; then
        mkdir -p "$AUTOSTART_DIR"
        cat << EOF > "$AUTOSTART_FILE"
[Desktop Entry]
Type=Application
Name=Calendario Dual Monitor
Comment=Avvio automatico script calendario
Exec=$(comando_terminale) "$SCRIPT_PATH"
Icon=utilities-terminal
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
        echo -e "${CLR_INFO}--> Avvio automatico configurato con successo!${CLR_RESET}"
        echo -e "    File autostart creato in: $AUTOSTART_FILE"
    else
        if [ -f "$AUTOSTART_FILE" ]; then
            rm -f "$AUTOSTART_FILE"
            echo -e "${CLR_WARN}--> Avvio automatico disabilitato/rimosso.${CLR_RESET}"
        else
            echo -e "--> Avvio automatico non configurato."
        fi
    fi
    echo
}

scrivi_nota_log() {
    mkdir -p "$LOG_DIR"
    printf '[%s] [INFO] Installer v%s: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$VERSIONE_INSTALLER" "$TIPO_TXT" >> "$LOG_DIR/calendario.log"
}

riepilogo_finale() {
    echo -e "${CLR_INFO}=== $1 ===${CLR_RESET}"
    echo "    Tipo di operazione: $TIPO_TXT"
    echo "    Script            : $SCRIPT_PATH"
    echo "    Comando rapido    : $CUSTOM_CMD"
    echo "    Log completo      : $LOG_DIR/calendario.log"
    echo "    Solo errori       : $LOG_DIR/error.log"
    echo "    Rilanciando questo installer, i valori di adesso saranno i predefiniti."
}

# ==============================================================================
# AVVIO
# ==============================================================================
carica_precedenti
classifica_versione

if [ "$1" = "--versione" ]; then
    if [ -f "$SCRIPT_PATH" ]; then
        echo "Versione installata        : ${VER_ATT:-non numerata (precedente alla 2.1)}"
    else
        echo "Versione installata        : nessuna (non ancora installato)"
    fi
    echo "Versione in questo installer: $VERSIONE_INSTALLER"
    exit 0
fi

# ==============================================================================
# MENU PRINCIPALE (SENZA COLORI NELLE OPZIONI 1-5)
# ==============================================================================
mostra_header
mostra_stato_versione
echo "Scegli un'opzione per procedere:"
echo " 1) Installa"
echo " 2) Reinstalla / Aggiorna (aggiorna i file mantenendo i log/struttura)"
echo " 3) Reinstalla da zero (Purge completo + Nuova installazione)"
echo " 4) Disinstalla (Purge completo di tutti i file dell'applicazione)"
echo " 5) Esci"
echo -e "${CLR_HEAD}------------------------------------------------------------${CLR_RESET}"
read -rp "Inserisci il numero dell'opzione scelta [1-5]: " SCELTA

case "$SCELTA" in
    1)
        mostra_header
        echo -e "${CLR_INFO}--> AVVIO INSTALLAZIONE...${CLR_RESET}"
        if [ -d "$TARGET_DIR" ]; then
            echo -e "${CLR_WARN}AVVISO: La cartella 'calendario' esiste già in $TARGET_DIR.${CLR_RESET}"
            echo -e "Se desideri aggiornarla scegli 'Reinstalla / Aggiorna' o 'Reinstalla da zero'."
            exit 1
        fi
        mostra_banner_tipo
        chiedi_config
        genera_script
        crea_comando_personalizzato
        gestisci_autostart
        controlla_dipendenze
        scrivi_nota_log
        riepilogo_finale "INSTALLAZIONE COMPLETATA CON SUCCESSO"
        ;;

    2)
        mostra_header
        echo -e "${CLR_INFO}--> AVVIO REINSTALLAZIONE / AGGIORNAMENTO...${CLR_RESET}"
        mostra_banner_tipo
        conferma_declassamento || exit 0
        chiedi_config
        genera_script
        crea_comando_personalizzato
        gestisci_autostart
        controlla_dipendenze
        scrivi_nota_log
        riepilogo_finale "REINSTALLAZIONE / AGGIORNAMENTO COMPLETATO"
        ;;

    3)
        mostra_header
        echo -e "${CLR_WARN}--> AVVIO REINSTALLAZIONE DA ZERO (PURGE + INSTALL)...${CLR_RESET}"
        mostra_banner_tipo
        conferma_declassamento || exit 0
        [ "$TIPO" != "nuova" ] && TIPO_TXT="reinstallazione da zero ($TIPO_TXT)"
        funzione_purge
        chiedi_config
        genera_script
        crea_comando_personalizzato
        gestisci_autostart
        controlla_dipendenze
        scrivi_nota_log
        riepilogo_finale "REINSTALLAZIONE DA ZERO COMPLETATA"
        ;;

    4)
        mostra_header
        echo -e "${CLR_ERR}--> AVVIO DISINSTALLAZIONE COMPLETA...${CLR_RESET}"
        read -rp "Sei sicuro di voler rimuovere tutti i file dell'applicazione? (s/n): " CONFERMA
        if [[ "$CONFERMA" =~ ^[Ss]$ ]]; then
            funzione_purge
            echo -e "${CLR_INFO}=== DISINSTALLAZIONE COMPLETATA ===${CLR_RESET}"
        else
            echo "Operazione annullata."
        fi
        ;;

    5)
        echo "Uscita."
        exit 0
        ;;

    *)
        echo -e "${CLR_ERR}Opzione non valida. Uscita.${CLR_RESET}"
        exit 1
        ;;
esac
