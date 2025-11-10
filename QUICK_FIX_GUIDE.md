# Quick Fix Guide - LeKnight v2.0.3

## 🎯 Problèmes Corrigés

### 1. ✅ Protocole HTTP/HTTPS respecté
**Avant:** `http://testphp.vulnweb.com` → autopilot testait en HTTPS
**Après:** `http://testphp.vulnweb.com` → autopilot teste en HTTP comme demandé

### 2. ✅ Subdomain false positive (projectdiscovery.io)
**Avant:** subfinder ajoutait `projectdiscovery.io` au scope
**Après:** Seuls les vrais subdomains du domaine cible sont ajoutés

### 3. ✅ Erreur fuzzing pipeline
**Avant:** `[: : integer expression expected`
**Après:** Plus d'erreurs de comparaison d'entiers

### 4. ✅ SQLi credentials
**Avant:** `db_add_credential: command not found`
**Après:** Fonction `db_credential_add()` appelée correctement

### 5. ✅ Module XSS remplacé
**Avant:** 300+ lignes de bash avec erreurs de syntaxe
**Après:** Module simplifié utilisant dalfox/nuclei (outils pros)

---

## 🚀 Installation Rapide

```bash
# 1. Vérifier que tous les fixes sont appliqués
bash verify_fixes.sh

# 2. Si tu as une base de données existante, migrer le schéma
bash core/db_migration_protocol.sh

# 3. Installer dalfox pour XSS (optionnel mais recommandé)
go install github.com/hahwul/dalfox/v2@latest

# 4. Tester !
./leknight.sh project create "Test HTTP"
./leknight.sh project add-target "http://testphp.vulnweb.com"
./leknight.sh autopilot
```

---

## 📋 Vérification Manuelle

### Test 1: Protocole HTTP préservé
```bash
# Créer un projet avec HTTP
./leknight.sh project create "Test"
./leknight.sh project add-target "http://example.com"

# Vérifier dans la DB
sqlite3 data/db/leknight.db "SELECT hostname, protocol FROM targets;"
# Devrait afficher: example.com|http
```

### Test 2: Subdomains filtrés
```bash
# Lancer un scan
./leknight.sh autopilot

# Vérifier qu'il n'y a pas de domaines non liés
sqlite3 data/db/leknight.db "SELECT hostname FROM targets;"
# NE devrait PAS contenir: projectdiscovery.io
```

### Test 3: Pas d'erreurs fuzzing
```bash
# Lancer autopilot et surveiller les logs
./leknight.sh autopilot 2>&1 | grep "integer expression"
# Devrait être vide (pas d'erreurs)
```

### Test 4: XSS détecté
```bash
# Si dalfox installé, il sera utilisé automatiquement
# Sinon, nuclei prendra le relais
# Dans les deux cas, pas d'erreurs de syntaxe
./leknight.sh autopilot 2>&1 | grep "syntax error"
# Devrait être vide
```

---

## 🔧 Modules Modifiés

### Core
- `core/database.sh` - Ajout colonne protocol
- `core/parsers.sh` - Validation subdomains
- `core/project.sh` - Extraction protocol

### Workflows
- `workflows/autopilot.sh` - Respect protocol stored
- `workflows/autopilot_advanced.sh` - Respect protocol stored
- `workflows/fuzzing_pipeline.sh` - Fix integer comparison
- `workflows/vulnerability_testing.sh` - XSS module simple

### Modules
- `modules/vulnerability_tests/sqli_module.sh` - Fix function name
- `modules/vulnerability_tests/xss_module_simple.sh` - **NOUVEAU**

### Setup
- `setup.sh` - Ajout dalfox

---

## 📊 Résultats Attendus

Après ces corrections, l'autopilot devrait :
- ✅ Respecter HTTP quand tu spécifies HTTP
- ✅ Ne pas ajouter de domaines non liés au scope
- ✅ Tourner sans erreurs de syntax ou d'integer
- ✅ Détecter les XSS avec dalfox/nuclei
- ✅ Stocker les credentials SQLi correctement

---

## 🐛 Si Problèmes Persistent

### Erreur: "protocol column not found"
```bash
# Migrer la base de données
bash core/db_migration_protocol.sh
```

### Erreur: "dalfox: command not found"
```bash
# Installer dalfox
go install github.com/hahwul/dalfox/v2@latest
# Ou laisser nuclei prendre le relais (fallback automatique)
```

### Erreur: "test_xss: command not found"
```bash
# Vérifier que le bon module est chargé
grep "xss_module_simple" workflows/vulnerability_testing.sh
# Devrait afficher la ligne avec xss_module_simple.sh
```

### Subdomains toujours incorrects
```bash
# Vérifier le fix dans parsers.sh
grep "Skipping unrelated domain" core/parsers.sh
# Devrait afficher le code de validation
```

---

## 📝 Détails Techniques

### Colonne Protocol
```sql
ALTER TABLE targets ADD COLUMN protocol TEXT DEFAULT 'http';
```

### Validation Subdomains
```bash
# Vérifie que subdomain.example.com finit par .example.com
if [[ "$subdomain" != *".${parent_domain}" ]]; then
    continue  # Skip
fi
```

### Module XSS Simplifié
```bash
# Utilise dalfox en priorité
if command -v dalfox &> /dev/null; then
    dalfox url "$url" --output results.txt
else
    # Fallback vers nuclei
    nuclei -u "$url" -t xss/
fi
```

---

## 🎓 Leçons Apprises

1. **Toujours valider l'appartenance au scope** - Pas juste valider le format
2. **Fournir des valeurs par défaut** - Pour éviter les comparaisons avec vides
3. **Utiliser des outils externes** - Au lieu de réinventer la roue en bash
4. **Préserver l'intention de l'utilisateur** - HTTP != HTTPS

---

## 📚 Documentation

- **BUGFIX_SUMMARY_v2.md** - Détails complets de chaque fix
- **PROTOCOL_PRESERVATION.md** - Guide de la feature protocol
- **verify_fixes.sh** - Script de vérification automatique

---

## ✨ Prochaines Versions

### v2.0.4 (Planifié)
- [ ] Améliorer validation DNS des subdomains
- [ ] Ajouter commande pour override protocol
- [ ] Indicateur visuel HTTP vs HTTPS dans TUI
- [ ] Tests automatisés CI/CD

---

**Version:** 2.0.3
**Date:** 2025-11-10
**Status:** ✅ Stable
