# Guide de Correctifs Autopilot - LeKnight v2.0

## 🎯 Résumé des Correctifs Appliqués

Tous les correctifs ont été appliqués pour résoudre le problème où l'autopilot s'arrêtait immédiatement sans scanner les targets.

### Problème Principal Identifié
L'autopilot utilisait une logique défaillante pour détecter les targets "non scannées". Dès qu'un scan commençait, la target disparaissait de la liste, ce qui stoppait immédiatement l'autopilot.

---

## ✅ Correctifs Appliqués

### 1. **Schéma de Base de Données** (core/database.sh)
- ✅ Ajout de `autopilot_status` (pending/completed/failed)
- ✅ Ajout de `autopilot_completed_at` (timestamp)
- ✅ Ajout d'index de performance pour optimiser les requêtes

### 2. **Fonction get_unscanned_targets()** (workflows/autopilot.sh:319-331)
- ✅ Modifiée pour utiliser `autopilot_status` au lieu de chercher l'absence de scans
- ✅ Requête SQL corrigée : `WHERE autopilot_status IS NULL OR autopilot_status = 'pending'`

### 3. **Fonction mark_target_scanned()** (workflows/autopilot.sh:349-360)
- ✅ Implémentation complète : met à jour le statut à 'completed'
- ✅ Enregistre le timestamp de complétion

### 4. **Fonction count_unscanned_targets()** (workflows/autopilot.sh:334-343)
- ✅ Mise à jour pour utiliser la nouvelle logique basée sur `autopilot_status`

### 5. **Boucle Principale Autopilot** (workflows/autopilot.sh:104-131)
- ✅ Correction du subshell : `while ... done < <(echo "$targets")` au lieu de pipe
- ✅ Les variables sont maintenant correctement propagées

### 6. **Compatibilité Stat** (core/wrapper.sh:59-63)
- ✅ Remplacement de `stat` par `wc -c` pour la portabilité Windows/Linux/macOS

### 7. **Parser de Subdomains** (core/parsers.sh:196-241)
- ✅ Validation ligne par ligne au lieu de regex permissive
- ✅ Nettoyage des entrées (espaces, casse, caractères spéciaux)
- ✅ Vérification de duplicatas avant insertion

### 8. **Logging et Debugging** (workflows/autopilot.sh)
- ✅ Ajout de `log_debug` pour tracer l'exécution
- ✅ Logging détaillé du nombre de targets trouvées
- ✅ Traçage du statut des targets à chaque itération

---

## 🚀 Comment Tester

### Étape 1 : Migrer la Base de Données Existante

Si tu as déjà une base de données existante, exécute le script de migration :

```bash
cd ~/Documents/GitHub/leknight-bash

# Rendre le script exécutable
chmod +x migrate-db.sh

# Exécuter la migration
./migrate-db.sh
```

Le script va :
- ✅ Créer un backup automatique de ta DB
- ✅ Ajouter les nouvelles colonnes
- ✅ Créer les index de performance
- ✅ Mettre à jour toutes les targets existantes en statut 'pending'
- ✅ Vérifier que la migration a réussi

**Important :** Si tu n'as pas encore de base de données, ignore cette étape. La nouvelle DB sera créée automatiquement avec le bon schéma.

---

### Étape 2 : Créer un Projet de Test

```bash
# Lancer LeKnight
./leknight-v2.sh

# Dans le menu :
# [1] Project Management
# [1] Create New Project

# Remplir :
Nom: Test Autopilot Fix
Description: Test des correctifs autopilot
Scope:
    example.com
    testphp.vulnweb.com
    [Ligne vide pour terminer]

# Confirmer : y
```

---

### Étape 3 : Lancer l'Autopilot

```bash
# Dans le menu :
# [4] Autopilot Mode
# [1] Start Autopilot

# Confirmer : y
```

---

### Étape 4 : Vérifier les Logs en Temps Réel

**Terminal 1** : Autopilot en cours d'exécution

**Terminal 2** : Surveiller les logs
```bash
# Ouvrir un second terminal
cd ~/Documents/GitHub/leknight-bash

# Suivre les logs en temps réel
tail -f data/logs/leknight.log
```

Tu devrais voir :
```
[2025-01-XX XX:XX:XX] [DEBUG] Checking for unscanned targets in project 1...
[2025-01-XX XX:XX:XX] [DEBUG] Found targets: 2 line(s)
[2025-01-XX XX:XX:XX] [INFO] Found 2 targets to scan
[2025-01-XX XX:XX:XX] [INFO] [1/2] Processing: example.com
[2025-01-XX XX:XX:XX] [DEBUG] Target identified as domain
[2025-01-XX XX:XX:XX] [INFO] Enumerating subdomains...
...
[2025-01-XX XX:XX:XX] [DEBUG] Target X marked as scanned by autopilot
[2025-01-XX XX:XX:XX] [DEBUG] Unscanned targets remaining: 15
[2025-01-XX XX:XX:XX] [INFO] Discovered 15 new targets, starting new iteration
```

---

### Étape 5 : Vérifier la Base de Données

```bash
# Vérifier les statuts des targets
sqlite3 data/db/leknight.db "SELECT id, hostname, autopilot_status, autopilot_completed_at FROM targets LIMIT 10;"

# Compter les targets par statut
sqlite3 data/db/leknight.db "SELECT autopilot_status, COUNT(*) FROM targets GROUP BY autopilot_status;"

# Résultat attendu :
# pending|5       <- Targets en attente
# completed|10    <- Targets scannées
```

---

### Étape 6 : Vérifier les Résultats

```bash
# Dans le menu LeKnight :
# [5] View Results
# [1] Project Dashboard

# Tu devrais voir :
# - Nombre de targets découvertes
# - Nombre de scans exécutés
# - Findings par sévérité
# - Credentials découvertes (si applicable)
```

---

## 🔍 Test de Non-Régression

### Test 1 : Autopilot avec 1 seul domaine
```bash
Scope: example.com
```
**Attendu** : L'autopilot doit :
1. Scanner example.com
2. Découvrir des subdomains via subfinder
3. Scanner automatiquement les subdomains découverts
4. S'arrêter quand tous les targets sont scannés (pas immédiatement !)

### Test 2 : Autopilot avec plusieurs domaines
```bash
Scope:
    example.com
    testphp.vulnweb.com
    scanme.nmap.org
```
**Attendu** : L'autopilot doit scanner les 3 domaines + tous les subdomains découverts

### Test 3 : Autopilot avec IP
```bash
Scope: 192.168.1.1
```
**Attendu** : L'autopilot doit :
1. Scanner les ports
2. Identifier les services web
3. Lancer des scans web si des ports HTTP/HTTPS sont ouverts

---

## 🐛 Debug si Problème

### Si l'autopilot s'arrête toujours immédiatement :

1. **Vérifier la migration de la DB**
```bash
sqlite3 data/db/leknight.db "PRAGMA table_info(targets);" | grep autopilot
```
Tu dois voir :
```
8|autopilot_status|TEXT|0|'pending'|0
9|autopilot_completed_at|DATETIME|0||0
```

2. **Vérifier les logs avec niveau DEBUG**
```bash
# Avant de lancer LeKnight
export LEKNIGHT_LOG_LEVEL=DEBUG
./leknight-v2.sh
```

3. **Vérifier les targets dans la DB**
```bash
sqlite3 data/db/leknight.db "SELECT * FROM targets;"
```

4. **Tester get_unscanned_targets manuellement**
```bash
# Source les fonctions
source workflows/autopilot.sh
source core/database.sh

# Tester la fonction
get_unscanned_targets 1  # Remplacer 1 par ton project_id
```

---

## 📊 Comparaison Avant/Après

### AVANT les correctifs :
```
ITERATION 1
Found 2 targets to scan
[1/2] Processing: example.com
  → Scan commence, DB créé dans 'scans' table
[2/2] Processing: test.com
  → Scan commence, DB créé dans 'scans' table

Checking for unscanned targets...
No more targets to scan  ← ❌ PROBLÈME : les targets viennent d'être scannées !
AUTOPILOT COMPLETED
Iterations: 1
```

### APRÈS les correctifs :
```
ITERATION 1
Found 2 targets to scan
[1/2] Processing: example.com
  → Scan terminé, autopilot_status = 'completed'
  → 15 subdomains découverts (autopilot_status = 'pending')
[2/2] Processing: test.com
  → Scan terminé, autopilot_status = 'completed'
  → 8 subdomains découverts (autopilot_status = 'pending')

Unscanned targets remaining: 23
Discovered 23 new targets, starting new iteration

ITERATION 2
Found 23 targets to scan
[1/23] Processing: sub1.example.com
...
[23/23] Processing: sub8.test.com

Unscanned targets remaining: 0
No new targets found, ending autopilot

AUTOPILOT COMPLETED
Iterations: 2
Total targets scanned: 25  ← ✅ Tous les targets ont été scannés !
```

---

## 🎉 Validation Réussie

L'autopilot fonctionne correctement si :
- ✅ Il fait **plusieurs itérations** (pas juste 1)
- ✅ Il découvre et scanne automatiquement les **subdomains**
- ✅ Le nombre de **targets scannées** augmente à chaque itération
- ✅ Les logs montrent `Discovered X new targets, starting new iteration`
- ✅ La DB contient des targets avec `autopilot_status = 'completed'`

---

## 📝 Notes Importantes

1. **Pas de suppression de données** : Les correctifs préservent toutes les données existantes
2. **Backup automatique** : Le script de migration crée automatiquement un backup
3. **Compatibilité** : Les anciens projets continueront de fonctionner normalement
4. **Réversible** : Si problème, tu peux restaurer le backup `.backup_*` dans `data/db/`

---

## 🤝 Support

Si tu rencontres des problèmes :

1. Vérifie les logs : `tail -f data/logs/leknight.log`
2. Active le DEBUG : `export LEKNIGHT_LOG_LEVEL=DEBUG`
3. Vérifie la DB : `sqlite3 data/db/leknight.db ".tables"`
4. Vérifie les colonnes : `sqlite3 data/db/leknight.db "PRAGMA table_info(targets);"`

---

**Bon scan ! 🎯⚔️**
