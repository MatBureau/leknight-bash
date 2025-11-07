#!/bin/bash

# LeKnight Quick Start - Script d'initialisation rapide
# Usage: ./start.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[*] Exécution du setup..."
bash ./setup.sh

echo "[*] Reset de la base de données..."
if [ -f "./data/leknight.db" ]; then
    rm -f ./data/leknight.db
    echo "[+] Base de données supprimée"
fi

# Recréer la DB via le script de migration
bash ./migrate-db.sh

echo "[+] Initialisation terminée!"
echo "[*] Lancement de LeKnight..."
echo ""

bash ./leknight.sh
