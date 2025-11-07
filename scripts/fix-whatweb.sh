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

        # Chercher les libs
        echo "[i] Recherche des bibliothèques..."
        find /usr -name "messages.rb" 2>/dev/null | head -3
    else
        echo "[✗] WhatWeb non installé"
    fi

    echo
    echo "[*] Solution alternative: Installation via gem Ruby"
    echo
    read -rp "Voulez-vous installer WhatWeb via gem Ruby? (y/n): " install_gem

    if [[ $install_gem =~ ^[Yy] ]]; then
        echo "[*] Installation de WhatWeb via gem..."
        sudo gem install whatweb

        if [ $? -eq 0 ]; then
            echo "[✓] WhatWeb installé via gem"
            echo "[i] Utilisez 'whatweb' depuis la ligne de commande"
        else
            echo "[✗] Échec de l'installation via gem"
        fi
    fi
fi

echo
echo "╔════════════════════════════════════════════════════════╗"
echo "║                     Terminé                            ║"
echo "╚════════════════════════════════════════════════════════╝"
