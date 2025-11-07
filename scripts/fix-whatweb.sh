#!/bin/bash

# fix-whatweb.sh - Fix WhatWeb library path issue on Kali Linux
# This script fixes the common "cannot load such file -- /usr/bin/lib/messages" error

echo "╔════════════════════════════════════════════════════════╗"
echo "║              WhatWeb Fix Script                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

echo "[*] Diagnostic de WhatWeb..."

# Vérifier où sont les libs
if [ -d "/usr/share/whatweb/lib" ]; then
    echo "[✓] Libs trouvées dans /usr/share/whatweb/lib"

    # Créer le symlink manquant
    if [ ! -L "/usr/bin/lib" ]; then
        echo "[*] Création du symlink /usr/bin/lib -> /usr/share/whatweb/lib"
        sudo ln -sf /usr/share/whatweb/lib /usr/bin/lib
        echo "[✓] Symlink créé"
    else
        echo "[i] Symlink existe déjà, vérification..."
        current_target=$(readlink /usr/bin/lib)
        if [ "$current_target" != "/usr/share/whatweb/lib" ]; then
            echo "[!] Symlink pointe vers le mauvais endroit: $current_target"
            echo "[*] Correction du symlink..."
            sudo rm /usr/bin/lib
            sudo ln -sf /usr/share/whatweb/lib /usr/bin/lib
            echo "[✓] Symlink corrigé"
        else
            echo "[✓] Symlink correct"
        fi
    fi

    # Tester WhatWeb
    echo
    echo "[*] Test de WhatWeb..."
    if whatweb --version 2>&1 | grep -q "WhatWeb"; then
        echo "[✓] WhatWeb fonctionne correctement !"
        echo
        whatweb --version
        echo
        echo "Vous pouvez maintenant utiliser WhatWeb dans LeKnight"
    else
        echo "[✗] WhatWeb ne fonctionne toujours pas"
        echo "[!] Erreur persistante:"
        whatweb --version 2>&1 | head -5
        echo
        echo "Essayez de réinstaller WhatWeb:"
        echo "  sudo apt-get remove --purge whatweb"
        echo "  sudo apt-get install whatweb"
    fi
elif [ -d "/usr/lib/whatweb/lib" ]; then
    echo "[✓] Libs trouvées dans /usr/lib/whatweb/lib"

    # Créer le symlink
    if [ ! -L "/usr/bin/lib" ]; then
        echo "[*] Création du symlink /usr/bin/lib -> /usr/lib/whatweb/lib"
        sudo ln -sf /usr/lib/whatweb/lib /usr/bin/lib
        echo "[✓] Symlink créé"
    fi

    # Tester
    echo "[*] Test de WhatWeb..."
    if whatweb --version 2>&1 | grep -q "WhatWeb"; then
        echo "[✓] WhatWeb fonctionne correctement !"
    fi
else
    echo "[✗] Libs WhatWeb non trouvées"
    echo
    echo "[*] Recherche de l'installation de WhatWeb..."

    # Chercher où est installé whatweb
    whatweb_path=$(which whatweb 2>/dev/null)
    if [ -n "$whatweb_path" ]; then
        echo "[i] WhatWeb trouvé: $whatweb_path"

        # Chercher tous les fichiers whatweb
        echo "[i] Recherche des fichiers WhatWeb..."
        whatweb_dirs=$(find /usr/share /usr/lib -type d -name "whatweb" 2>/dev/null)

        if [ -n "$whatweb_dirs" ]; then
            echo "[i] Répertoires WhatWeb trouvés:"
            echo "$whatweb_dirs"

            # Chercher le répertoire lib
            for dir in $whatweb_dirs; do
                if [ -d "$dir/lib" ]; then
                    echo
                    echo "[✓] Libs trouvées dans: $dir/lib"
                    echo "[*] Création du symlink /usr/bin/lib -> $dir/lib"
                    sudo ln -sf "$dir/lib" /usr/bin/lib

                    # Test
                    echo "[*] Test de WhatWeb..."
                    if whatweb --version 2>&1 | grep -q "WhatWeb"; then
                        echo "[✓] WhatWeb fonctionne correctement !"
                        whatweb --version
                        exit 0
                    fi
                fi
            done
        fi

        # Si pas trouvé, chercher plugins
        echo
        echo "[i] Recherche alternative des plugins..."
        find /usr/share /usr/lib -type d -name "plugins" 2>/dev/null | grep whatweb | head -3
    else
        echo "[✗] WhatWeb non installé"
    fi

    echo
    echo "[*] Solution de contournement"
    echo "WhatWeb semble cassé sur cette installation Kali."
    echo "Options:"
    echo "  1. Réinstaller complètement:"
    echo "     sudo apt-get remove --purge whatweb"
    echo "     sudo apt-get autoremove"
    echo "     sudo apt-get update"
    echo "     sudo apt-get install whatweb"
    echo
    echo "  2. Cloner depuis GitHub (recommandé):"
    echo "     git clone https://github.com/urbanadventurer/WhatWeb.git ~/whatweb"
    echo "     sudo ln -sf ~/whatweb/whatweb /usr/local/bin/whatweb"
    echo
    read -rp "Voulez-vous cloner WhatWeb depuis GitHub? (y/n): " install_github

    if [[ $install_github =~ ^[Yy] ]]; then
        echo "[*] Clonage de WhatWeb depuis GitHub..."
        cd ~
        if [ -d "whatweb" ]; then
            echo "[i] Répertoire whatweb existe déjà, mise à jour..."
            cd whatweb && git pull
        else
            git clone https://github.com/urbanadventurer/WhatWeb.git whatweb
        fi

        if [ $? -eq 0 ]; then
            echo "[✓] WhatWeb cloné avec succès"
            echo "[*] Création du lien symbolique..."
            sudo ln -sf ~/whatweb/whatweb /usr/local/bin/whatweb

            # Test
            echo "[*] Test de WhatWeb..."
            whatweb --version
            echo
            echo "[✓] WhatWeb installé depuis GitHub et fonctionnel !"
        else
            echo "[✗] Échec du clonage"
        fi
    fi
fi

echo
echo "╔════════════════════════════════════════════════════════╗"
echo "║                     Terminé                            ║"
echo "╚════════════════════════════════════════════════════════╝"
