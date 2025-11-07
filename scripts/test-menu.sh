#!/bin/bash

# Test simple du menu project management

# Setup
export LEKNIGHT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RESET="$(tput sgr0)"
BOLD="$(tput bold)"
RED="$(tput setaf 5)"
BLUE="$(tput setaf 7)"
BRIGHT_RED="${BOLD}$(tput setaf 3)"
BRIGHT_BLUE="${BOLD}$(tput setaf 7)"
GREEN="$(tput setaf 2)"

export RESET BOLD RED BLUE BRIGHT_RED BRIGHT_BLUE GREEN

# Source modules
echo "Sourcing modules..."
source "${LEKNIGHT_ROOT}/core/logger.sh"
source "${LEKNIGHT_ROOT}/core/utils.sh"
source "${LEKNIGHT_ROOT}/core/database.sh"
source "${LEKNIGHT_ROOT}/core/project.sh"

echo "Modules sourced successfully"
echo

# Initialize database
db_init

echo
echo "=== Testing Project Management Menu ==="
echo

while true; do
    echo "PROJECT MANAGEMENT"
    echo
    echo "  [1] Create New Project"
    echo "  [2] List Projects"
    echo "  [3] Load Project"
    echo "  [0] Exit"
    echo

    read -rp "Select option: " choice

    echo "You selected: $choice"

    case "$choice" in
        1)
            echo
            echo "=== CREATE PROJECT ==="
            read -rp "Project Name: " name
            read -rp "Description: " desc
            read -rp "Scope: " scope

            echo
            echo "Calling: project_create \"$name\" \"$desc\" \"$scope\""

            result=$(project_create "$name" "$desc" "$scope" 2>&1)
            echo "Result: $result"

            read -rp "Press enter to continue..."
            ;;

        2)
            echo
            echo "=== LIST PROJECTS ==="
            project_list
            read -rp "Press enter to continue..."
            ;;

        3)
            echo
            echo "=== LOAD PROJECT ==="
            read -rp "Project ID or name: " identifier
            project_load "$identifier"
            read -rp "Press enter to continue..."
            ;;

        0)
            echo "Exiting..."
            exit 0
            ;;

        *)
            echo "Invalid option: $choice"
            sleep 2
            ;;
    esac

    clear
done
