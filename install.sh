#!/bin/bash
# ==============================================================================
# Installer Interattivo per Calendario Dual-Monitor su Raspberry Pi / Linux
# ==============================================================================

# Percorsi principali
USER_HOME="$HOME"
TARGET_DIR="$USER_HOME/calendario"
LOG_DIR="$TARGET_DIR/logs"
SCRIPT_NAME="calendario.sh"
SCRIPT_PATH="$TARGET_DIR/$SCRIPT_NAME"
AUTOSTART_DIR="$USER_HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/calendario-dual.desktop"

# Definizione dei Colori per Output Terminale
CLR_RESET="\e[0m"
CLR_TIME="\e[1;36m"     # Ciano Bold
CLR_INFO="\e[1;32m"     # Verde Bold
CLR_WARN="\e[1;33m"     # Giallo Bold
CLR_ERR="\e[1;31m"      # Rosso Bold
CLR_HEAD="\e[1;35m"     # Magenta Bold

mostra_header() {
    clear
    echo -e "${CLR_HEAD}============================================================${CLR_RESET}"
    echo -e "${CLR_HEAD}       INSTALLER INTERATTIVO: CALENDARIO DUAL-MONITOR       ${CLR_RESET}"
    echo -e "${CLR_HEAD}============================================================${CLR_RESET}"
    echo
}

funzione_purge() {
    echo -e "${CLR_WARN}--> [PURGE] RIMOZIONE DI TUTTI I FILE DELL'APPLICAZIONE...${CLR_RESET}"
    
    if [ -f "$AUTOSTART_FILE" ]; then
        rm -f "$AUTOSTART_FILE"
        echo -e "    - Rimosso file di avvio automatico ($AUTOSTART_FILE)."
    fi

    if [ -d "$USER_HOME/chrome-dual-profili" ]; then
        rm -rf "$USER_HOME/chrome-dual-profili"
        echo -e "    - Rimossa cartella profili Chromium (~/chrome-dual-profili)."
    fi

    if [ -d "$TARGET_DIR" ]; then
        rm -rf "$TARGET_DIR"
        echo -e "    - Rimossa la cartella principale dell'applicazione ($TARGET_DIR)."
    fi

    echo -e "${CLR_INFO}--> Purge completato con successo.${CLR_RESET}"
    echo
}

chiedi_url() {
    echo -e "${CLR_HEAD}------------------------------------------------------------${CLR_RESET}"
    echo -e "${CLR_HEAD}CONFIGURAZIONE LINK DA PROIETTARE${CLR_RESET}"
    echo -e "${CLR_HEAD}------------------------------------------------------------${CLR_RESET}"
    read -rp "Inserisci l'URL per il monitor di SINISTRA [default: https://www.google.com]: " INPUT_URL_SIN
    URL_SINISTRA="${INPUT_URL_SIN:-https://www.google.com}"

    read -rp "Inserisci l'URL per il monitor di DESTRA   [default: https://www.youtube.com]: " INPUT_URL_DES
    URL_DESTRA="${INPUT_URL_DES:-https://www.youtube.com}"
    echo
}

genera_script() {
    echo -e "${CLR_INFO}--> Generazione della struttura e dello script principale ($SCRIPT_NAME)...${CLR_RESET}"
    mkdir -p "$LOG_DIR"

    cat << EOF > "$SCRIPT_PATH"
#!/bin/bash
[ -z "\$BASH_VERSION" ] && exec bash "\$0" "\$@"

# Se lanciato con sudo, Chromium non parte: si rilancia come utente reale.
if [ "\$(id -u)" -eq 0 ] && [ -n "\$SUDO_USER" ] && [ "\$SUDO_USER" != "root" ]; then
    UHOME=\$(getent passwd "\$SUDO_USER" | cut -d: -f6)
    UID_U=\$(id -u "\$SUDO_USER")
    XA="\${XAUTHORITY:-}"
    if [ -z "\$XA" ]; then
        XA=\$(ls /run/user/"\$UID_U"/.mutter-Xwaylandauth.* 2>/dev/null | head -1)
        [ -z "\$XA" ] && XA="\$UHOME/.Xauthority"
    fi
    echo "Script lanciato con sudo: lo rilancio come utente '\$SUDO_USER'..."
    exec sudo -u "\$SUDO_USER" env \\
        HOME="\$UHOME" \\
        DISPLAY="\${DISPLAY:-:0}" \\
        XAUTHORITY="\$XA" \\
        XDG_RUNTIME_DIR="/run/user/\$UID_U" \\
        bash "\$(readlink -f "\$0")" "\$@"
fi

# ---- CONFIGURAZIONE PERCORSI E LOG --------------------------------------
DIR_APP="\$HOME/calendario"
DIR_LOGS="\$DIR_APP/logs"
LOG_FULL="\$DIR_LOGS/calendario.log"
LOG_ERR="\$DIR_LOGS/error.log"

mkdir -p "\$DIR_LOGS"

# ---- COLORI OUTPUT TERMINALE --------------------------------------------
C_RST="\e[0m"
C_TM="\e[1;36m"   # Ciano (Ora)
C_INF="\e[1;32m"  # Verde (Info)
C_WRN="\e[1;33m"  # Giallo (Warning)
C_ERR="\e[1;31m"  # Rosso (Errore)

# ---- CONFIGURAZIONE APPLICAZIONE ---------------------------------------
MESSAGGIO="INSERISCI QUI IL TUO TESTO"
URL_SINISTRA="\${1:-$URL_SINISTRA}"
URL_DESTRA="\${2:-$URL_DESTRA}"
DELAY=10            # secondi di attesa prima di iniziare
TENTATIVI=5         # tentativi di rilevamento monitor
PAUSA=3             # secondi tra un tentativo e l'altro
BROWSER_FORZATO=""  # percorso opzionale browser
INTERVALLO_CONTROLLO=120
CHIUDI_SE_MONITOR_CAMBIANO=1
# ------------------------------------------------------------------------

export DISPLAY="\${DISPLAY:-:0}"

# Strip dei colori ANSI prima di scrivere nei file di log
pulisci_ansi() {
    echo -e "\$1" | sed -r "s/\x1B\[[0-9;]*[a-zA-Z]//g"
}

log() {
    local stamp="\${C_TM}[\$(date '+%Y-%m-%d %H:%M:%S')]\${C_RST}"
    local msg="\$stamp \${C_INF}[INFO]\${C_RST} \$*"
    echo -e "\$msg"
    pulisci_ansi "\$msg" >> "\$LOG_FULL"
}

log_warn() {
    local stamp="\${C_TM}[\$(date '+%Y-%m-%d %H:%M:%S')]\${C_RST}"
    local msg="\$stamp \${C_WRN}[WARN]\${C_RST} \$*"
    echo -e "\$msg"
    pulisci_ansi "\$msg" >> "\$LOG_FULL"
}

log_error() {
    local stamp="\${C_TM}[\$(date '+%Y-%m-%d %H:%M:%S')]\${C_RST}"
    local msg="\$stamp \${C_ERR}[ERROR]\${C_RST} \$*"
    echo -e "\$msg" >&2
    pulisci_ansi "\$msg" >> "\$LOG_FULL"
    pulisci_ansi "\$msg" >> "\$LOG_ERR"
}

info() {
    local msg="           \$*"
    echo -e "\$msg"
    pulisci_ansi "\$msg" >> "\$LOG_FULL"
}

SESSIONE="\${XDG_SESSION_TYPE:-}"
if [ -z "\$SESSIONE" ]; then
    if [ -S "\${XDG_RUNTIME_DIR:-/run/user/\$(id -u)}/\${WAYLAND_DISPLAY:-wayland-0}" ]; then
        SESSIONE="wayland"
    else
        SESSIONE="x11"
    fi
fi
SISTEMA=\$(. /etc/os-release 2>/dev/null && echo "\$PRETTY_NAME")
MODELLO=""
[ -r /proc/device-tree/model ] && MODELLO=\$(tr -d '\0' < /proc/device-tree/model)

attendi_chiusura() {
    echo
    read -rp "Premi INVIO per chiudere questo terminale..." _
}

centro_in_monitor() {
    local wid=\$1 i=\$2 out wx wy ww wh
    out=\$(xdotool getwindowgeometry --shell "\$wid" 2>/dev/null) || return 2
    wx=\$(echo "\$out" | sed -n 's/^X=//p');     wy=\$(echo "\$out" | sed -n 's/^Y=//p')
    ww=\$(echo "\$out" | sed -n 's/^WIDTH=//p'); wh=\$(echo "\$out" | sed -n 's/^HEIGHT=//p')
    [ -z "\$wx" ] || [ -z "\$ww" ] && return 2
    CX=\$((wx + ww / 2)); CY=\$((wy + wh / 2))
    if [ "\$CX" -ge "\${MX[\$i]}" ] && [ "\$CX" -lt \$((MX[i] + MW[i])) ] &&
       [ "\$CY" -ge "\${MY[\$i]}" ] && [ "\$CY" -lt \$((MY[i] + MH[i])) ]; then
        return 0
    fi
    return 1
}

finestre_chromium() {
    xdotool search --onlyvisible --class "chrom" 2>/dev/null | sort -u
}

verifica_finestra() {
    local i=\$1 prima=\$2 wid="" n id out w h area best=0
    if ! command -v xdotool >/dev/null; then
        if [ -z "\$AVVISO_XDOTOOL" ]; then
            info "Verifica posizione saltata: installa xdotool e wmctrl"
            AVVISO_XDOTOOL=1
        fi
        return
    fi
    for ((n = 1; n <= 10; n++)); do
        best=0; wid=""
        for id in \$(finestre_chromium); do
            grep -qx "\$id" <<< "\$prima" && continue
            out=\$(xdotool getwindowgeometry --shell "\$id" 2>/dev/null)
            w=\$(echo "\$out" | sed -n 's/^WIDTH=//p'); h=\$(echo "\$out" | sed -n 's/^HEIGHT=//p')
            [ -z "\$w" ] && continue
            area=\$((w * h))
            if [ "\$area" -gt "\$best" ]; then best=\$area; wid=\$id; fi
        done
        [ -n "\$wid" ] && break
        sleep 1
    done
    if [ -z "\$wid" ]; then
        info "Nessuna nuova finestra Chromium trovata: posizione non verificabile."
        return
    fi
    centro_in_monitor "\$wid" "\$i"
    case \$? in
        0) log "Posizione OK: finestra sul monitor \${ETICHETTE[\$i]} (centro \$CX,\$CY)."; return ;;
        2) info "Impossibile leggere la geometria della finestra."; return ;;
    esac

    log_warn "La finestra NON è sul monitor \${ETICHETTE[\$i]} (centro \$CX,\$CY)."
    if ! command -v wmctrl >/dev/null; then
        info "Per correggere automaticamente installa wmctrl (sudo apt install wmctrl)."
        return
    fi
    info "Provo a spostarla in \${MX[\$i]},\${MY[\$i]}..."
    wmctrl -i -r "\$wid" -b remove,fullscreen
    xdotool windowmove "\$wid" "\${MX[\$i]}" "\${MY[\$i]}"
    sleep 1
    wmctrl -i -r "\$wid" -b add,fullscreen
    sleep 1
    if centro_in_monitor "\$wid" "\$i"; then
        log "Correzione riuscita: ora la finestra è sul monitor \${ETICHETTE[\$i]} (centro \$CX,\$CY)."
    else
        log_error "Correzione NON riuscita (centro \$CX,\$CY). Il window manager ignora lo spostamento."
    fi
}

PIDS=()
AVVISO_XDOTOOL=""
CHIUSURA_FATTA=0
MOTIVO_USCITA=""

conta_monitor_attivi() {
    xrandr --query 2>/dev/null | grep ' connected' | grep -cE '[0-9]+x[0-9]+\+[0-9]+\+[0-9]+'
}

istanza_viva() {
    local i=\$1
    { [ -n "\${PIDS[\$i]}" ] && kill -0 "\${PIDS[\$i]}" 2>/dev/null; } ||
        pgrep -f "chrome-dual-profili/monitor-\$((i + 1))" >/dev/null 2>&1
}

chiudi_browser() {
    [ "\$CHIUSURA_FATTA" -eq 1 ] && return
    CHIUSURA_FATTA=1
    [ "\${#PIDS[@]}" -eq 0 ] && return
    log "Chiusura delle finestre del browser in corso..."
    local i n vivo
    for i in "\${!PIDS[@]}"; do
        kill -TERM -- "-\${PIDS[\$i]}" 2>/dev/null
        pkill -TERM -f "chrome-dual-profili/monitor-\$((i + 1))" 2>/dev/null
    done
    for ((n = 0; n < 10; n++)); do
        vivo=0
        for i in "\${!PIDS[@]}"; do istanza_viva "\$i" && vivo=1; done
        [ "\$vivo" -eq 0 ] && break
        sleep 0.5
    done
    for i in "\${!PIDS[@]}"; do
        if istanza_viva "\$i"; then
            info "Finestra \$((i + 1)) ancora attiva: forzo la chiusura (SIGKILL)."
            kill -KILL -- "-\${PIDS[\$i]}" 2>/dev/null
            pkill -KILL -f "chrome-dual-profili/monitor-\$((i + 1))" 2>/dev/null
        fi
    done
    log "Finestre chiuse."
}

errore_fatale() {
    echo
    log_error "\$*"
    chiudi_browser
    attendi_chiusura
    exit 1
}

uscita_script() {
    local rc=\$?
    if [ "\${#PIDS[@]}" -gt 0 ] && [ "\$CHIUSURA_FATTA" -eq 0 ]; then
        echo
        log_error "\${MOTIVO_USCITA:-Script terminato inaspettatamente (codice \$rc)}: chiudo le finestre."
        chiudi_browser
    elif [ -n "\$MOTIVO_USCITA" ]; then
        log_error "\$MOTIVO_USCITA"
    fi
}

trap 'MOTIVO_USCITA="Interruzione da tastiera (Ctrl+C)"; exit 130' INT
trap 'MOTIVO_USCITA="Segnale di terminazione (SIGTERM)"; exit 143' TERM
trap 'MOTIVO_USCITA="Terminale chiuso (SIGHUP)"; exit 129' HUP
trap uscita_script EXIT

log "=== Avvio automatico doppio schermo ==="
log "Sistema: \${SISTEMA:-sconosciuto}\${MODELLO:+ (\$MODELLO)} | utente: \$(id -un) | sessione: \$SESSIONE"
log "Link SINISTRA: \$URL_SINISTRA | DESTRA: \$URL_DESTRA"

if [ "\$(id -u)" -eq 0 ]; then
    log_warn "ATTENZIONE: script eseguito come root: Chromium non partirà senza --no-sandbox."
fi

OZONE_ARGS=()
if [ "\$SESSIONE" = "wayland" ]; then
    OZONE_ARGS=(--ozone-platform=x11)
    log "Sessione Wayland: Chromium sarà avviato in modalità X11 (XWayland)."
fi

for ((s = DELAY; s > 0; s--)); do
    printf "\r\e[1;36m[%s]\e[0m \e[1;33m[WAIT]\e[0m Avvio tra %2d secondi...   " "\$(date +%H:%M:%S)" "\$s"
    sleep 1
done
[ "\$DELAY" -gt 0 ] && echo

if [ -n "\$BROWSER_FORZATO" ]; then
    BROWSER=\$(command -v "\$BROWSER_FORZATO")
else
    BROWSER=\$(command -v chromium-browser || command -v chromium || command -v google-chrome-stable || command -v google-chrome)
fi

if [ -z "\$BROWSER" ]; then
    log_error "Nessun browser Chromium/Chrome trovato nel PATH."
    attendi_chiusura
    exit 1
fi

VERSIONE=\$("\$BROWSER" --version 2>/dev/null | head -1)
log "Browser: \$BROWSER (\${VERSIONE:-versione sconosciuta})"

if ! command -v xrandr >/dev/null; then
    log_error "Il comando xrandr non è installato."
    attendi_chiusura
    exit 1
fi

MONITORS=()
NOMI=()
for ((t = 1; t <= TENTATIVI; t++)); do
    RAW=\$(xrandr --query 2>&1)
    if [ \$? -ne 0 ]; then
        log_warn "xrandr ha restituito un errore: \$RAW"
    fi

    ELENCO=\$(echo "\$RAW" | grep ' connected' | while read -r nome _; do
        geom=\$(echo "\$RAW" | grep "^\$nome " | grep -oE '[0-9]+x[0-9]+\+[0-9]+\+[0-9]+' | head -1)
        [ -n "\$geom" ] && echo "\$(echo "\$geom" | cut -d+ -f2) \$nome \$geom"
    done | sort -n)

    MONITORS=()
    NOMI=()
    while read -r _x nome geom; do
        [ -z "\$nome" ] && continue
        NOMI+=("\$nome")
        MONITORS+=("\$geom")
    done <<< "\$ELENCO"

    [ "\${#MONITORS[@]}" -eq 2 ] && break
    if [ "\$t" -lt "\$TENTATIVI" ]; then
        log_warn "Monitor attivi: \${#MONITORS[@]} (ne servono 2), riprovo tra \$PAUSA secondi (\$t/\$TENTATIVI)..."
        sleep "\$PAUSA"
    fi
done

if [ "\${#MONITORS[@]}" -ne 2 ]; then
    log_error "Condizione NON soddisfatta: monitor attivi = \${#MONITORS[@]} (ne servono 2)."
    echo "\$MESSAGGIO"
    attendi_chiusura
    exit 1
fi

RE='^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)\$'
MW=(); MH=(); MX=(); MY=()
for i in 0 1; do
    if [[ "\${MONITORS[\$i]}" =~ \$RE ]]; then
        MW[\$i]=\${BASH_REMATCH[1]}; MH[\$i]=\${BASH_REMATCH[2]}
        MX[\$i]=\${BASH_REMATCH[3]}; MY[\$i]=\${BASH_REMATCH[4]}
    else
        log_error "Geometria non interpretabile: '\${MONITORS[\$i]}'"
        attendi_chiusura
        exit 1
    fi
done

ETICHETTE=("SINISTRA" "DESTRA")
log "Monitor SINISTRA: \${NOMI[0]} \${MW[0]}x\${MH[0]} (\${MX[0]},\${MY[0]}) | DESTRA: \${NOMI[1]} \${MW[1]}x\${MH[1]} (\${MX[1]},\${MY[1]})"

if [ "\${MX[0]}" -eq "\${MX[1]}" ] && [ "\${MY[0]}" -eq "\${MY[1]}" ]; then
    log_error "I due monitor hanno la stessa posizione (\${MX[0]},\${MY[0]}): sono in MIRRORING."
    attendi_chiusura
    exit 1
elif [ \$((MX[0] + MW[0])) -gt "\${MX[1]}" ]; then
    log_error "I monitor non sono affiancati in orizzontale."
    attendi_chiusura
    exit 1
fi

URLS=("\$URL_SINISTRA" "\$URL_DESTRA")

for i in 0 1; do
    PROFILO="\$HOME/chrome-dual-profili/monitor-\$((i + 1))"
    CLASSE="chrome-dual-\$((i + 1))"

    log "Avvio \${ETICHETTE[\$i]} su \${NOMI[\$i]} (\${MX[\$i]},\${MY[\$i]}): \${URLS[\$i]}"

    PRIMA=""
    command -v xdotool >/dev/null && PRIMA=\$(finestre_chromium)

    setsid "\$BROWSER" \\
        --user-data-dir="\$PROFILO" \\
        --class="\$CLASSE" \\
        "\${OZONE_ARGS[@]}" \\
        --window-position="\${MX[\$i]},\${MY[\$i]}" \\
        --start-fullscreen \\
        --no-first-run \\
        --noerrdialogs \\
        --disable-infobars \\
        --disable-session-crashed-bubble \\
        --hide-crash-restore-bubble \\
        --new-window "\${URLS[\$i]}" >>"\$LOG_FULL" 2>&1 &
    PID=\$!
    PIDS[\$i]=\$PID

    sleep 4

    if kill -0 "\$PID" 2>/dev/null; then
        verifica_finestra "\$i" "\$PRIMA"
    else
        log_error "Il browser del monitor \${ETICHETTE[\$i]} è terminato subito."
        errore_fatale "Avvio fallito sul monitor \${ETICHETTE[\$i]}."
    fi
done

log "Tutto avviato. Supervisione attiva."

while true; do
    sleep "\$INTERVALLO_CONTROLLO" & wait \$!

    for i in 0 1; do
        istanza_viva "\$i" || errore_fatale "La finestra del monitor \${ETICHETTE[\$i]} si è chiusa inaspettatamente."
    done

    if [ "\$CHIUDI_SE_MONITOR_CAMBIANO" -eq 1 ]; then
        for ((k = 1; k <= 3; k++)); do
            N=\$(conta_monitor_attivi)
            [ "\$N" -eq 2 ] && break
            [ "\$k" -lt 3 ] && sleep "\$PAUSA"
        done
        [ "\$N" -ne 2 ] && errore_fatale "I monitor attivi non sono più 2 (ora \$N)."
    fi
done
EOF

    chmod +x "$SCRIPT_PATH"
    echo -e "${CLR_INFO}--> Script principale creato in $SCRIPT_PATH${CLR_RESET}"
}

gestisci_autostart() {
    echo -e "${CLR_HEAD}------------------------------------------------------------${CLR_RESET}"
    echo -e "${CLR_HEAD}CONFIGURAZIONE AVVIO AUTOMATICO (AUTOSTART)${CLR_RESET}"
    echo -e "${CLR_HEAD}------------------------------------------------------------${CLR_RESET}"
    read -rp "Vuoi eseguire l'applicazione automaticamente ad ogni avvio del sistema? (s/n) [default: s]: " RISP_AUTO
    RISP_AUTO="${RISP_AUTO:-s}"

    if [[ "$RISP_AUTO" =~ ^[Ss]$ ]]; then
        mkdir -p "$AUTOSTART_DIR"
        cat << EOF > "$AUTOSTART_FILE"
[Desktop Entry]
Type=Application
Name=Calendario Dual Monitor
Comment=Avvio automatico script calendario
Exec=x-terminal-emulator -e bash "$SCRIPT_PATH"
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

# ==============================================================================
# MENU PRINCIPALE
# ==============================================================================
mostra_header
echo -e "Scegli un'opzione per procedere:"
echo -e " ${CLR_INFO}1)${CLR_RESET} Installa"
echo -e " ${CLR_INFO}2)${CLR_RESET} Reinstalla (Aggiorna file e mantenendo i log/struttura)"
echo -e " ${CLR_WARN}3)${CLR_RESET} Reinstalla da zero (Purge completo + Nuova installazione)"
echo -e " ${CLR_ERR}4)${CLR_RESET} Disinstalla (Purge completo di tutti i file dell'applicazione)"
echo -e " ${CLR_INFO}5)${CLR_RESET} Esci"
echo -e "${CLR_HEAD}------------------------------------------------------------${CLR_RESET}"
read -rp "Inserisci il numero dell'opzione scelta [1-5]: " SCELTA

case "$SCELTA" in
    1)
        mostra_header
        echo -e "${CLR_INFO}--> AVVIO INSTALLAZIONE...${CLR_RESET}"
        if [ -d "$TARGET_DIR" ]; then
            echo -e "${CLR_WARN}AVVISO: La cartella 'calendario' esiste già in $TARGET_DIR.${CLR_RESET}"
            echo -e "Se desideri aggiornarla scegli 'Reinstalla' o 'Reinstalla da zero'."
            exit 1
        fi
        chiedi_url
        genera_script
        gestisci_autostart
        echo -e "${CLR_INFO}=== INSTALLAZIONE COMPLETATA CON SUCCESSO ===${CLR_RESET}"
        ;;

    2)
        mostra_header
        echo -e "${CLR_INFO}--> AVVIO REINSTALLAZIONE (AGGIORNAMENTO)...${CLR_RESET}"
        chiedi_url
        genera_script
        gestisci_autostart
        echo -e "${CLR_INFO}=== REINSTALLAZIONE COMPLETATA ===${CLR_RESET}"
        ;;

    3)
        mostra_header
        echo -e "${CLR_WARN}--> AVVIO REINSTALLAZIONE DA ZERO (PURGE + INSTALL)...${CLR_RESET}"
        funzione_purge
        chiedi_url
        genera_script
        gestisci_autostart
        echo -e "${CLR_INFO}=== REINSTALLAZIONE DA ZERO COMPLETATA ===${CLR_RESET}"
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
