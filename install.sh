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
    echo -e "${CLR_HEAD}       INSTALLER INTERATTIVO: CALENDARIO DUAL-MONITOR${CLR_RESET}"
    echo -e "${CLR_HEAD}                       versione $VERSIONE_INSTALLER${CLR_RESET}"
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
    [ "$a" != "$b" ] && [ "$(printf '\%s\n\%s\n' "$a" "$b" \vert{} sort -V \vert{} head -n1)" = "$a" ]
}

classifica_versione() {
    if [ ! -f "$SCRIPT_PATH" ]; then
        TIPO="nuova";         TIPO_TXT="nuova installazione, versione $VERSIONE_INSTALLER"
    elif [ -z "$VER_ATT" ]; then
        TIPO="aggiornamento"; TIPO_TXT="aggiornamento da una versione non numerata (precedente alla 2.1) alla $VERSIONE_INSTALLER"
    elif [ "$VER_ATT" = "$VERSIONE_INSTALLER" ]; then
        TIPO="uguale";        TIPO_TXT="reinstallazione della stessa versione ($VERSIONE_INSTALLER)"
    elif versione_minore "$VER_ATT" "$VERSIONE_INSTALLER"; then
        TIPO="aggiornamento"; TIPO_TXT="aggiornamento da $VER_ATT a$VERSIONE_INSTALLER"
    else
        TIPO="declassamento"; TIPO_TXT="ritorno a una versione più vecchia: da $VER_ATT a$VERSIONE_INSTALLER"
    fi
}

mostra_stato_versione() {
    case "$TIPO" in
        nuova)         echo -e "Stato: ${CLR_WARN}nessuna installazione trovata${CLR_RESET} (questo installer contiene la versione$VERSIONE_INSTALLER)" ;;
        uguale)        echo -e "Stato: installata la versione ${CLR_INFO}$VER_ATT${CLR_RESET}, uguale a quella di questo installer" ;;
        aggiornamento) echo -e "Stato: installata ${CLR_WARN}${VER_ATT:-una versione non numerata}${CLR_RESET} ->${CLR_INFO}AGGIORNAMENTO DISPONIBILE${CLR_RESET} alla$VERSIONE_INSTALLER" ;;
        declassamento) echo -e "Stato: installata la $VER_ATT,${CLR_ERR}più recente${CLR_RESET} di questo installer ($VERSIONE_INSTALLER)" ;;
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

    if [ -L "$SYMLINK_SYS" ] \vert{}\vert{} [ -f "$SYMLINK_SYS" ]; then
        sudo rm -f "$SYMLINK_SYS" 2>/dev/null && echo -e "    - Rimosso comando globale ($SYMLINK_SYS)."
    fi
    if [ -L "$SYMLINK_USER" ] \vert{}\vert{} [ -f "$SYMLINK_USER" ]; then
        rm -f "$SYMLINK_USER" && echo -e "    - Rimosso comando utente ($SYMLINK_USER)."
    fi

    if [ -d "$PROFILI_DIR" ]; then
