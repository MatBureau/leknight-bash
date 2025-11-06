# 🚀 Guide de Déploiement VPS - LeKnight v2.0.1

## ⚡ Installation Rapide

### 1. Cloner et Mettre à Jour

```bash
# Si déjà cloné, mettre à jour
cd ~/leknight-bash
git pull origin main

# Sinon, cloner
git clone https://github.com/MatBureau/leknight-bash.git
cd leknight-bash
```

### 2. Appliquer les Correctifs

```bash
# Rendre les scripts exécutables
chmod +x *.sh
chmod +x core/*.sh workflows/*.sh reports/*.sh

# Migrer la base de données
./migrate-db.sh
```

### 3. Lancer LeKnight

```bash
./leknight-v2.sh
```

---

## 🔧 Résolution des Problèmes Courants

### Problème 1 : "Invalid target" avec URLs

**Symptôme** :
```
[✗] Invalid target: http://example.com
```

**Solution** : Les correctifs v2.0.1 règlent ce problème. Après `git pull`, redémarre LeKnight.

---

### Problème 2 : Erreur SQL "near ",": syntax error"

**Symptôme** :
```
Parse error near line 1: near ",": syntax error
VALUES (2, 'example.com', '', , '', '');
```

**Solution** : Les correctifs v2.0.1 gèrent maintenant les valeurs NULL correctement.

---

### Problème 3 : Autopilot trouve 0 targets

**Symptôme** :
```
Targets Discovered: 0
Scans Executed: 0
```

**Diagnostic** :
```bash
# Vérifier que la migration a fonctionné
sqlite3 data/db/leknight.db "PRAGMA table_info(targets);" | grep autopilot

# Devrait afficher :
# 8|autopilot_status|TEXT|0|'pending'|0
# 9|autopilot_completed_at|DATETIME|0||0
```

**Solution si rien ne s'affiche** :
```bash
# Réexécuter la migration
./migrate-db.sh

# Vérifier à nouveau
sqlite3 data/db/leknight.db "PRAGMA table_info(targets);" | grep autopilot
```

---

### Problème 4 : Dépôt Caddy bloque apt-get

**Symptôme** :
```
E: The repository 'https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version InRelease' is not signed.
```

**Solution** :
```bash
# Supprimer le dépôt Caddy
sudo rm -f /etc/apt/sources.list.d/caddy*
sudo rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg

# Mettre à jour
sudo apt-get update

# Installer les dépendances essentielles manuellement
sudo apt-get install -y sqlite3 curl wget git jq nmap nikto
```

---

## 📋 Checklist de Test Complet

### Étape 1 : Créer un Projet

```bash
./leknight-v2.sh

# [1] Project Management
# [1] Create New Project
```

**Remplir** :
```
Nom: Test VPS
Description: Test des correctifs v2.0.1
Scope:
    testphp.vulnweb.com
    scanme.nmap.org
    [Ligne vide pour terminer]
```

---

### Étape 2 : Vérifier que les Targets sont Créées

```bash
# Terminal 2
sqlite3 ~/leknight-bash/data/db/leknight.db "SELECT id, hostname, autopilot_status FROM targets;"

# Devrait afficher :
# 1|testphp.vulnweb.com|pending
# 2|scanme.nmap.org|pending
```

---

### Étape 3 : Lancer l'Autopilot

```bash
# Dans LeKnight
# [4] Autopilot Mode
# [1] Start Autopilot
# Confirmer : Y
```

**Attendu** :
```
═══════════════════════════════════════════════════════
  AUTOPILOT ITERATION 1
═══════════════════════════════════════════════════════

Found 2 targets to scan
[1/2] Processing: testphp.vulnweb.com
[i] Target identified as domain name
[i] Enumerating subdomains...
...
```

**❌ PAS attendu** :
```
[i] No more targets to scan  (immédiatement)
```

---

### Étape 4 : Surveiller les Logs

```bash
# Terminal 2
tail -f ~/leknight-bash/data/logs/leknight.log

# Tu devrais voir :
[DEBUG] Checking for unscanned targets in project 1...
[DEBUG] Found targets: 2 line(s)
[INFO] Found 2 targets to scan
[INFO] [1/2] Processing: testphp.vulnweb.com
[DEBUG] Target identified as domain
...
[DEBUG] Target 1 marked as scanned by autopilot
[DEBUG] Unscanned targets remaining: 15  ← Nouveaux subdomains découverts
[INFO] Discovered 15 new targets, starting new iteration
```

---

### Étape 5 : Vérifier la DB Après le Scan

```bash
# Compter les targets par statut
sqlite3 ~/leknight-bash/data/db/leknight.db "SELECT autopilot_status, COUNT(*) FROM targets GROUP BY autopilot_status;"

# Devrait afficher quelque chose comme :
# completed|5
# pending|10
```

---

## ✅ Test Réussi Si...

- ✅ Les URLs sont acceptées dans le scope (pas d'erreur "Invalid target")
- ✅ Aucune erreur SQL "near ',':"
- ✅ L'autopilot fait **plusieurs itérations** (pas juste 1)
- ✅ Les subdomains sont découverts automatiquement
- ✅ Les logs montrent "Discovered X new targets, starting new iteration"
- ✅ La DB contient des targets avec `autopilot_status = 'completed'`

---

## 🐛 Debug Avancé

### Activer le Mode DEBUG

```bash
# Avant de lancer LeKnight
export LEKNIGHT_LOG_LEVEL=DEBUG
./leknight-v2.sh
```

### Inspecter la DB Manuellement

```bash
cd ~/leknight-bash

# Ouvrir la DB
sqlite3 data/db/leknight.db

# Commandes utiles
.tables                          # Lister toutes les tables
.schema targets                  # Voir le schéma de la table targets
SELECT * FROM projects;          # Lister les projets
SELECT * FROM targets LIMIT 10;  # Lister les 10 premières targets
SELECT autopilot_status, COUNT(*) FROM targets GROUP BY autopilot_status;
.quit                            # Quitter
```

### Réinitialiser Complètement

```bash
# ATTENTION : Cela supprime TOUTES les données !
cd ~/leknight-bash
rm -rf data/
./leknight-v2.sh  # Créera une nouvelle DB vierge
```

---

## 📞 Support

Si problème persistant :

1. **Vérifier la version** :
   ```bash
   cd ~/leknight-bash
   git log --oneline -5
   # Doit contenir les commits de fix autopilot
   ```

2. **Partager les logs** :
   ```bash
   tail -100 data/logs/leknight.log
   ```

3. **Vérifier le schéma DB** :
   ```bash
   sqlite3 data/db/leknight.db ".schema targets"
   ```

---

**Bon scan ! 🎯⚔️**
