# LeKnight v2.0 - Guide de Démarrage Rapide

## 🚀 Installation sur Kali Linux

```bash
# Cloner le repo
cd ~
git clone https://github.com/MatBureau/leknight-bash.git
cd leknight-bash

# Rendre les scripts exécutables
chmod +x setup.sh leknight-v2.sh
chmod +x core/*.sh workflows/*.sh reports/*.sh

# Lancer l'installation (installe les dépendances)
./setup.sh

# Démarrer LeKnight
./leknight-v2.sh
```

## 🎯 Premier Projet - Exemple Complet

### Scénario : Scan d'une application web

```bash
# 1. Lancer LeKnight
./leknight-v2.sh

# 2. Créer un projet
Menu > [1] Project Management > [1] Create New Project

Nom: "Test WebApp"
Description: "Scan de test pour target.com"
Scope: target.com
        *.target.com
        [Entrée sur ligne vide pour terminer]

# 3. Le projet est maintenant chargé automatiquement

# 4. Lancer l'Autopilot
Menu > [4] Autopilot Mode > [1] Start Autopilot

# L'autopilot va :
# ✓ Analyser target.com
# ✓ Détecter qu'il s'agit d'un domaine
# ✓ Énumérer les sous-domaines
# ✓ Scanner chaque sous-domaine
# ✓ Détecter les ports ouverts
# ✓ Identifier les vulnérabilités
# ✓ Extraire les credentials
# ✓ Tout stocker dans la base de données

# 5. Consulter les résultats
Menu > [5] View Results > [1] Project Dashboard

# 6. Générer le rapport
Menu > [6] Generate Reports > [1] Markdown Report
```

## 🤖 Mode Autopilot - Utilisation Avancée

### Scan Autonome avec Scope Multiple

```bash
# Créer un projet
Nom: "Bug Bounty - AcmeCorp"
Scope:
    example.com
    *.example.com
    api.example.com
    192.168.1.0/24

# Lancer Autopilot
# Il va automatiquement :
# - Scanner les 4 entrées du scope
# - Découvrir tous les sous-domaines
# - Scanner chaque sous-domaine découvert
# - Énumérer les IPs du /24
# - Scanner les ports de chaque IP
# - Lancer des scans web sur les services HTTP/HTTPS trouvés
```

### Monitoring Continu

```bash
# Pour surveiller une cible en continu
Menu > Autopilot Mode > Monitor Mode

Intervalle: 3600  # Scan toutes les heures

# Parfait pour :
# - Détecter de nouveaux sous-domaines
# - Surveiller l'apparition de nouvelles vulnérabilités
# - Monitoring à long terme
```

### Rescan des Cibles à Haut Risque

```bash
# Après un premier scan, rescanner uniquement les targets
# qui ont des findings Critical/High

Menu > Autopilot Mode > Rescan High-Value Targets

# Plus rapide et ciblé
```

## 📊 Workflows Manuels

### Web Reconnaissance

```bash
Menu > Workflows > Web Reconnaissance

Target: https://example.com

Depth:
  [1] Quick   - 3 outils, ~5 min
  [2] Medium  - 6 outils, ~15 min (recommandé)
  [3] Deep    - 10 outils, ~30 min

# Quick: WhatWeb, Nikto, SSL Scan
# Medium: + FFUF, Nuclei, Subfinder
# Deep: + Screenshot, WordPress scan, JS analysis
```

### Network Sweep

```bash
Menu > Workflows > Network Sweep

Target: 192.168.1.0/24 (ou une IP unique)

Depth:
  [1] Quick   - Scan rapide des ports
  [2] Medium  - + détection services, OS, scripts NSE
  [3] Deep    - + scan complet 65535 ports, SMB, SNMP

# Adapté pour :
# - Audits réseau internes
# - Reconnaissance infrastructure
# - Pentests traditionnels
```

## 🔍 Consulter les Résultats

### Dashboard Projet

```bash
Menu > View Results > Project Dashboard

Affiche:
├── Nombre de targets scannées
├── Nombre total de scans
├── Findings par sévérité (Critical, High, Medium, Low, Info)
├── Credentials découvertes
├── Activité récente
└── Top findings
```

### Filtrer par Sévérité

```bash
Menu > View Results > Critical/High Findings

# Voir uniquement les vulns importantes
# Idéal pour prioriser le travail
```

### Credentials Découvertes

```bash
Menu > View Results > Discovered Credentials

# Liste toutes les credentials extraites :
# - Usernames WordPress
# - Passwords crackés
# - Tokens API
# - Credentials Hydra
# - Dumps SQL
```

## 📄 Génération de Rapports

### Rapport Markdown (Recommandé)

```bash
Menu > Generate Reports > Markdown Report

# Génère un rapport complet avec :
# ✓ Executive Summary
# ✓ Statistiques du projet
# ✓ Findings par sévérité (avec détails)
# ✓ Liste des targets testées
# ✓ Credentials découvertes
# ✓ Historique des scans
# ✓ Méthodologie

# Fichier sauvegardé dans :
# data/projects/[ID]/reports/[nom]_[timestamp].md
```

### Export CSV

```bash
Menu > Generate Reports > CSV Export

# Export tous les findings au format CSV
# Parfait pour Excel/Google Sheets
# Colonnes : Severity, Type, Title, Description, Target, Date
```

### Export JSON

```bash
Menu > Generate Reports > JSON Export

# Export complet au format JSON
# Utile pour :
# - Intégration avec d'autres outils
# - Scripts personnalisés
# - Backup programmatique
```

## 🛠️ Scans Manuels (Si besoin de contrôle fin)

```bash
Menu > Manual Scans

# Lancer un outil spécifique manuellement
# Exemples :

# Nmap
Tool: Nmap
Target: 192.168.1.50
Args: -sV -sC -p-

# Nuclei
Tool: Nuclei
Target: https://example.com
Args: -severity critical,high

# SQLMap
Tool: SQLMap
Target: https://example.com/page?id=1
Args: --batch --level=5

# Le résultat sera automatiquement :
# - Capturé dans un fichier
# - Parsé pour extraire les findings
# - Stocké dans la base de données
# - Visible dans le dashboard
```

## 📁 Structure des Données

```bash
leknight-bash/
├── data/
│   ├── db/
│   │   └── leknight.db           # Base SQLite
│   │
│   ├── projects/
│   │   └── [project_id]/
│   │       ├── scans/            # Outputs bruts des outils
│   │       ├── reports/          # Rapports générés
│   │       ├── screenshots/      # Captures d'écran
│   │       └── metadata.txt      # Infos projet
│   │
│   ├── logs/
│   │   └── leknight.log          # Logs système
│   │
│   └── exports/
│       └── *.json, *.csv         # Exports
```

## 🎓 Cas d'Usage Réels

### Bug Bounty - Reconnaissance Initiale

```bash
1. Créer projet avec scope du programme
2. Lancer Autopilot
3. Laisser tourner 2-4 heures
4. Consulter Critical/High findings
5. Vérifier manuellement les findings prometteurs
6. Soumettre les vulns valides
```

### Pentest - Audit Complet

```bash
1. Créer projet avec scope complet (web + réseau)
2. Lancer Network Sweep (Deep) sur les IPs
3. Lancer Web Recon (Deep) sur les domaines
4. Analyser les résultats
5. Exploitation manuelle si autorisé
6. Générer rapport professionnel
```

### Monitoring Continu

```bash
1. Créer projet "Production Monitoring"
2. Définir scope = vos assets
3. Lancer Autopilot Monitor Mode (interval 6h)
4. Recevoir alertes sur nouveaux findings
5. Réagir rapidement aux changements
```

## 🔧 Dépannage Rapide

### "No project loaded"
```bash
# Solution : Charger un projet
Menu > Project Management > Load Project
```

### "Tool not found"
```bash
# Solution : Installer l'outil
sudo apt-get install [nom-outil]

# Ou relancer setup
./setup.sh
```

### Base de données corrompue
```bash
# Solution : Backup et reinit
cp data/db/leknight.db data/db/leknight.db.backup
rm data/db/leknight.db
./leknight-v2.sh  # Réinitialise auto
```

### Trop de résultats / Spam
```bash
# Solution : Nettoyer les anciens scans
Menu > Settings > Database Cleanup
Days: 7  # Supprime scans > 7 jours
```

## 💡 Tips & Astuces

### 1. Scope Intelligent
```bash
# Utilisez des wildcards pour les sous-domaines
*.example.com
*.api.example.com

# Utilisez CIDR pour les réseaux
192.168.1.0/24
10.0.0.0/8
```

### 2. Autopilot en Background
```bash
# Lancer en background avec nohup
nohup ./leknight-v2.sh <<EOF &
4
1
y
EOF

# Les résultats seront dans la DB
# Consultables plus tard
```

### 3. Export Régulier
```bash
# Exporter régulièrement en JSON pour backup
Menu > Generate Reports > JSON Export

# Permet de restaurer ou migrer les données
```

### 4. Monitoring des Logs
```bash
# Suivre les logs en temps réel
tail -f data/logs/leknight.log

# Ou dans l'interface
Menu > View Results > View Logs
```

### 5. Plusieurs Projets en Parallèle
```bash
# LeKnight supporte plusieurs projets
# Créez un projet par programme bug bounty
# Ou par client en pentest

# Basculer entre projets :
Menu > Project Management > Load Project
```

## 🎯 Prochaines Étapes

Maintenant que vous maîtrisez les bases :

1. **Testez sur un environnement de test** (HackTheBox, TryHackMe, etc.)
2. **Personnalisez les workflows** selon vos besoins
3. **Ajoutez vos outils préférés** dans les parsers
4. **Partagez vos retours** pour améliorer LeKnight

## 📞 Support

- **Issues GitHub** : https://github.com/MatBureau/leknight-bash/issues
- **Documentation complète** : README-v2.md
- **Changelog** : CHANGELOG.md

---

**Bonne chasse ! 🎯⚔️**
