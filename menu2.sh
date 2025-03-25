#!/bin/bash

# Feste Variablen
M_DIR=$(dirname "$(realpath "$0")")

# Lese Skript-Pfad aus spfad Datei
M_SCR=""
if [ -f "$M_DIR/spfad" ] && [ -r "$M_DIR/spfad" ]; then
    M_SCR=$(head -n 1 "$M_DIR/spfad" | tr -d '\n')
    if [ ! -d "$M_SCR" ]; then
        zenity --error --title="Fehler" --text="Der Pfad in spfad existiert nicht:\n$M_SCR" --width=500
        exit 1
    fi
else
    zenity --error --title="Fehler" --text="Datei spfad nicht gefunden oder nicht lesbar in:\n$M_DIR" --width=500
    exit 1
fi

# Dynamische Variablen
M_Index=""
M_Sudo=0
M_Para=0
M_Exe=""
M_Des=""
M_Msg=""
M_Nme=""

# Funktion für Fehlerbehandlung
error_handler() {
    local exit_code=$?
    local line_no=$1
    local command=$2
    
    M_Msg="Fehler in Zeile $line_no: $command (Exit-Code: $exit_code)"
    zenity --error --title="Fehler" --text="$M_Msg" --width=500
    return $exit_code
}

# Funktion zum Öffnen eines Terminalfensters im Vordergrund
open_terminal() {
    local command=$1
    local terminal=""
    local term_cmd=""
    
    # Priorisierte Liste von Terminal-Emulatoren mit Vordergrund-Optionen
    if command -v gnome-terminal &>/dev/null; then
        terminal="gnome-terminal"
        term_cmd="gnome-terminal -- bash -c"
    elif command -v konsole &>/dev/null; then
        terminal="konsole"
        term_cmd="konsole --hold -e bash -c"
    elif command -v xfce4-terminal &>/dev/null; then
        terminal="xfce4-terminal"
        term_cmd="xfce4-terminal --hold -e bash -c"
    elif command -v mate-terminal &>/dev/null; then
        terminal="mate-terminal"
        term_cmd="mate-terminal --disable-factory -e bash -c"
    elif command -v xterm &>/dev/null; then
        terminal="xterm"
        term_cmd="xterm -hold -e bash -c"
    else
        zenity --error --title="Fehler" --text="Kein Terminal-Emulator gefunden!" --width=300
        return 1
    fi

    # Führe Befehl aus und bringe Terminal in den Vordergrund
    $term_cmd "$command; echo; read -p 'Drücke Enter zum Beenden...'" &

    # Warte kurz bis Terminal gestartet ist
    sleep 0.5

    # Versuche Terminal in den Vordergrund zu bringen
    if command -v wmctrl &>/dev/null; then
        case "$terminal" in
            "gnome-terminal") wmctrl -a "Terminal" ;;
            "konsole") wmctrl -a "Konsole" ;;
            "xfce4-terminal") wmctrl -a "Terminal" ;;
            *) wmctrl -a "$terminal" ;;
        esac
    elif command -v xdotool &>/dev/null; then
        xdotool search --class "$terminal" windowactivate
    fi
}

# Funktion zum Laden der Beschreibung
load_description() {
    M_Des="Keine Beschreibung verfügbar"
    [ -f "$M_DIR/menu.desc" ] && {
        local desc_line=$(grep "^$M_Index " "$M_DIR/menu.desc")
        [ -n "$desc_line" ] && M_Des=$(echo "$desc_line" | cut -d' ' -f2-)
    }
}

# Funktion zur Parameterabfrage
get_parameters() {
    local params=()
    [ $M_Para -eq 0 ] && return 0

    [ ! -f "$M_DIR/menu.para" ] && {
        zenity --error --title="Fehler" --text="Parameterdatei menu.para nicht gefunden!" --width=400
        return 1
    }

    while IFS= read -r line; do
        local p_num=$(echo "$line" | awk '{print $2}')
        local p_type=$(echo "$line" | awk '{print $3}')
        M_Msg=$(echo "$line" | cut -d' ' -f4-)

        local input=$(zenity --entry --title="Parameter $p_num" \
                           --text="$M_Msg" \
                           --width=400)
        [ $? -ne 0 ] && return 1

        case "$p_type" in
            "N")
                [[ ! "$input" =~ ^[0-9]+$ ]] && {
                    zenity --error --title="Fehler" \
                           --text="Numerischer Wert erforderlich für Parameter $p_num!" \
                           --width=300
                    return 1
                }
                ;;
            "T")
                [ -z "$input" ] && {
                    zenity --error --title="Fehler" \
                           --text="Texteingabe darf nicht leer sein!" \
                           --width=300
                    return 1
                }
                ;;
        esac

        params+=("$input")
    done < <(grep "^$M_Index " "$M_DIR/menu.para")

    echo "${params[@]}"
}

# Hauptmenü Funktion
show_menu() {
    [ ! -f "$M_DIR/menu.list" ] && {
        zenity --error --title="Fehler" --text="Menüdatei menu.list nicht gefunden!" --width=400
        exit 1
    }

    menu_items=()
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        M_Index=${line:0:3}
        M_Exe=$(echo "$line" | awk '{print $2}')
        load_description
        
        menu_items+=("$M_Index")
        menu_items+=("$M_Exe - $M_Des")
    done < "$M_DIR/menu.list"

    M_Index=$(zenity --list --title="Hauptmenü" --text="Bitte wählen Sie:" \
                    --column="ID" --column="Beschreibung" \
                    --width=700 --height=500 \
                    "${menu_items[@]}")

    [ -z "$M_Index" ] && exit 0

    # Setze Variablen basierend auf Auswahl
    selected_line=$(grep "^$M_Index " "$M_DIR/menu.list")
    M_Exe=$(echo "$selected_line" | awk '{print $2}')
    M_Sudo=$(echo "$selected_line" | awk '{print $3}')
    M_Para=$(echo "$selected_line" | awk '{print $4}')
    M_Nme="$M_Exe.sh"
    load_description
}

# Hauptprogramm
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

# Prüfe ob wmctrl oder xdotool installiert ist für Vordergrund-Funktion
if ! command -v wmctrl &>/dev/null && ! command -v xdotool &>/dev/null; then
    if zenity --question --title="Hinweis" \
              --text="Für die Vordergrund-Funktion wird wmctrl oder xdotool benötigt.\nSoll ich wmctrl installieren?" \
              --width=400; then
        sudo apt-get install wmctrl
    fi
fi

while true; do
    show_menu
    
    # Überprüfe ob Skript existiert
    if [ ! -f "$M_SCR/$M_Nme" ]; then
        zenity --error --title="Fehler" \
               --text="Skript $M_Nme nicht gefunden in:\n$M_SCR" \
               --width=400
        continue
    fi

    # Parameter abfragen falls benötigt
    parameters=""
    if [ $M_Para -gt 0 ]; then
        parameters=$(get_parameters)
        [ $? -ne 0 ] && continue
    fi

    # Baue Ausführungskommando zusammen
    command="cd '$M_SCR' && "
    [ $M_Sudo -eq 1 ] && command+="sudo "
    command+="./'$M_Nme' $parameters"

    # Bestätigungsdialog
    if zenity --question --title="Bestätigung" \
              --text="Soll das Skript ausgeführt werden?\n\nSkript: $M_Nme\nBeschreibung: $M_Des" \
              --width=500; then
        open_terminal "$command" || continue
    fi
done
