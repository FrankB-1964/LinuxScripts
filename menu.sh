#!/bin/bash

# Ermittle den Ordner, in dem dieses Skript liegt
Menu_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ordner für die Scripte (kann als Argument übergeben werden)
Script_dir="${1:-/home/frank/Dokumente}"

# Pfad zur menu.list und menu.desc
MENU_LIST="$Menu_dir/menu.list"
MENU_DESC="$Menu_dir/menu.desc"

# Überprüfe, ob die Dateien menu.list und menu.desc existieren
if [[ ! -f "$MENU_LIST" ]]; then
    echo "Fehler: $MENU_LIST nicht gefunden."
    exit 1
fi
if [[ ! -f "$MENU_DESC" ]]; then
    echo "Fehler: $MENU_DESC nicht gefunden."
    exit 1
fi

# Funktion zur Anzeige einer Messagebox
show_message() {
    local message="$1"
    zenity --info --text="$message" --title="Info"
}

# Funktion zur Abfrage eines zusätzlichen Parameters
ask_for_parameter() {
    local parameter=$(zenity --entry --title="Parameter eingeben" --text="Bitte benötigten Parameter eingeben:")
    if [[ -z "$parameter" ]]; then
        echo "Fehler: Kein Parameter eingegeben."
        return 1
    else
        echo "$parameter"
    fi
}

# Funktion zur Anzeige des Menüs
show_menu() {
    clear
    echo "========== Script-Menü =========="
    while IFS= read -r line; do
        # Extrahiere die Menünummer, den Scriptnamen, den sudo-Parameter und den Parameter für die Abfrage
        menu_number=$(echo "$line" | awk '{print $1}')
        script_name=$(echo "$line" | awk '{print $2}')
        sudo_flag=$(echo "$line" | awk '{print $3}')
        ask_parameter=$(echo "$line" | awk '{print $4}')

        # Zeige den Menüpunkt an
        echo "$menu_number. $script_name"

        # Zeige die Beschreibung an, falls vorhanden
        description=$(grep "^$menu_number " "$MENU_DESC" | cut -d' ' -f2-)
        if [[ -n "$description" ]]; then
            echo "    $description"
        fi
    done < "$MENU_LIST"
    echo "0. Beenden"
    echo "================================="
}

# Funktion zur Ausführung des Scripts in einem neuen Terminal
run_script() {
    local script_name=$1
    local sudo_flag=$2
    local ask_parameter=$3

    # Pfad zum Script
    local script_path="$Script_dir/$script_name.sh"

    # Überprüfe, ob das Script existiert
    if [[ ! -f "$script_path" ]]; then
        show_message "Fehler: Script '$script_name.sh' nicht gefunden."
        return 1
    fi

    # Abfrage nach einem zusätzlichen Parameter, falls notwendig
    local additional_parameter=""
    if [[ "$ask_parameter" -eq 1 ]]; then
        additional_parameter=$(ask_for_parameter)
        if [[ $? -ne 0 ]]; then
            echo "Fehler: Abfrage des Parameters fehlgeschlagen."
            return 1
        fi
    fi

    # Öffne ein neues Terminalfenster und führe das Script aus
    if [[ "$sudo_flag" -eq 1 ]]; then
        gnome-terminal -- bash -c "sudo bash '$script_path' '$additional_parameter' 2> >(zenity --error --text=\"\$(cat)\" --title=\"Fehler\"); if [ \$? -eq 0 ]; then zenity --info --text=\"Alles erledigt, zurück zum Menü mit Enter\" --title=\"Info\"; fi; exit"
    else
        gnome-terminal -- bash -c "bash '$script_path' '$additional_parameter' 2> >(zenity --error --text=\"\$(cat)\" --title=\"Fehler\"); if [ \$? -eq 0 ]; then zenity --info --text=\"Alles erledigt, zurück zum Menü mit Enter\" --title=\"Info\"; fi; exit"
    fi
}

# Hauptprogramm
while true; do
    show_menu
    read -p "Wählen Sie einen Menüpunkt (0 zum Beenden): " choice

    if [[ $choice -eq 0 ]]; then
        echo "Menü beendet."
        break
    else
        # Suche die ausgewählte Zeile in der menu.list
        selected_line=$(grep "^$choice " "$MENU_LIST")
        if [[ -n "$selected_line" ]]; then
            # Extrahiere den Scriptnamen, den sudo-Parameter und den Parameter für die Abfrage
            script_name=$(echo "$selected_line" | awk '{print $2}')
            sudo_flag=$(echo "$selected_line" | awk '{print $3}')
            ask_parameter=$(echo "$selected_line" | awk '{print $4}')

            # Führe das Script aus
            run_script "$script_name" "$sudo_flag" "$ask_parameter"
        else
            echo "Fehler: Ungültige Auswahl."
        fi
    fi
    read -p "Drücken Sie eine Taste, um zum Menü zurückzukehren..."
done
