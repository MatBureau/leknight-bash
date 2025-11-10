#!/bin/bash

# Script de correction des erreurs grep
# Corrige la syntaxe grep -o "---HTTP_CODE:[0-9]*"

echo "[*] Fixing grep syntax errors in vulnerability modules..."

# Fonction pour corriger un fichier
fix_file() {
    local file=$1
    echo "[*] Fixing: $file"

    # Backup
    cp "$file" "${file}.bak"

    # Correction 1: grep -o "---HTTP_CODE:[0-9]*"
    # Remplacer par grep -oE -- "HTTP_CODE:[0-9]+"
    sed -i 's/grep -o "---HTTP_CODE:\[0-9\]\*"/grep -oE -- "HTTP_CODE:[0-9]+" | sed "s\/HTTP_CODE:\/\/"/g' "$file"

    # Correction 2: grep -o '---HTTP_CODE:[0-9]*'
    sed -i "s/grep -o '---HTTP_CODE:\[0-9\]\*'/grep -oE -- 'HTTP_CODE:[0-9]+' | sed 's\/HTTP_CODE:\/\/'/g" "$file"

    # Correction 3: Alternative avec cut
    sed -i 's/grep -o "\-\-\-HTTP_CODE:\[0-9\]\*"/grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2/g' "$file"

    echo "[✓] Fixed: $file"
}

# Corriger tous les modules de vulnérabilités
for module in modules/vulnerability_tests/*.sh; do
    if [ -f "$module" ]; then
        fix_file "$module"
    fi
done

# Corriger les modules d'exploitation
for module in modules/exploitation/*.sh; do
    if [ -f "$module" ]; then
        fix_file "$module"
    fi
done

echo ""
echo "[✓] All grep syntax errors fixed!"
echo "[i] Backup files saved with .bak extension"
echo "[i] You can remove them with: rm modules/**/*.bak"
