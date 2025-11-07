#!/bin/bash

# LeKnight Quick Start - Script d'initialisation rapide
# Usage: ./start.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[*] Rendre tous les scripts exécutables..."
find . -type f -name "*.sh" -exec chmod +x {} \;

echo "[*] Exécution du setup..."
./setup.sh

echo "[*] Reset de la base de données..."
if [ -f "./data/leknight.db" ]; then
    rm -f ./data/leknight.db
    echo "[+] Base de données supprimée"
fi

# Recréer la DB via le script de migration
./migrate-db.sh

echo "[+] Initialisation terminée!"
echo "[*] Lancement de LeKnight..."
echo ""

./leknight.sh
