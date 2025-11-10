# Bug Fixes - LeKnight v2.0.1

## Corrections Appliquées

### 1. ✅ **Erreurs grep** (Corrigé)

**Problème :**
```bash
grep: unrecognized option '---HTTP_CODE:[0-9]*'
```

**Cause :** grep interprétait le triple tiret `---` comme une option invalide.

**Solution :** Changement de pattern dans 5 modules :
```bash
# Avant:
grep -o "---HTTP_CODE:[0-9]*"

# Après:
grep -oE "HTTP_CODE:[0-9]+"
```

**Fichiers corrigés :**
- `modules/vulnerability_tests/csrf_module.sh`
- `modules/vulnerability_tests/idor_module.sh`
- `modules/vulnerability_tests/sqli_module.sh`
- `modules/vulnerability_tests/ssrf_module.sh`
- `modules/vulnerability_tests/xspa_module.sh`

**Test :**
```bash
# Vérifier qu'il n'y a plus d'erreurs grep
grep -r 'grep -o "---HTTP_CODE' modules/
# Doit retourner : aucun résultat
```

---

### 2. ✅ **Fonctions XSS manquantes** (Corrigé)

**Problème :**
```bash
test_reflected_xss: command not found
test_stored_xss: command not found
test_dom_xss: command not found
```

**Cause :** Les fonctions étaient définies mais pas exportées initialement.

**Solution :** Exports ajoutés dans `xss_module.sh` :
```bash
export -f test_xss
export -f test_reflected_xss
export -f test_stored_xss
export -f test_dom_xss
export -f test_xss_parameter
export -f extract_url_parameters
export -f urlencode
export -f detect_xss_context
export -f save_xss_evidence
```

**Fichier corrigé :**
- `modules/vulnerability_tests/xss_module.sh`

**Test :**
```bash
# Vérifier les exports
grep "export -f test_reflected_xss" modules/vulnerability_tests/xss_module.sh
# Doit retourner : export -f test_reflected_xss
```

---

### 3. ✅ **Faux positifs RCE time-based** (Corrigé)

**Problème :**
```bash
[⚠] [RCE] Time-based command injection found in parameter 'cmd'!
[⚠] [RCE] Time-based command injection found in parameter 'command'!
[⚠] [RCE] Time-based command injection found in parameter 'exec'!
...
```

Détection de RCE sur presque tous les paramètres testés (faux positifs massifs).

**Cause :**
- Seuil trop bas (4 secondes) détectait les timeouts réseau comme du RCE
- Pas de comparaison au temps baseline
- Réseau lent ou latence élevée = faux positif

**Ancienne logique (buggy) :**
```bash
if [ $response_time -ge 4 ]; then
    # Détecte RCE !
fi
```

**Nouvelle logique (corrigée) :**
```bash
# Calculate expected time (5 second delay + baseline)
local baseline_secs=$((baseline_time / 1000))
[ $baseline_secs -lt 1 ] && baseline_secs=1
local expected_time=$((baseline_secs + 5))

# Only report if response time is significantly longer than baseline
# AND close to expected delay (within 2 seconds)
local time_diff=$((response_time - expected_time))
[ $time_diff -lt 0 ] && time_diff=$((-time_diff))

if [ $response_time -ge 5 ] && [ $time_diff -le 2 ]; then
    # Vrai RCE détecté !
fi
```

**Améliorations :**
1. ✅ Compare maintenant au temps baseline
2. ✅ Seuil augmenté à 5 secondes minimum
3. ✅ Vérifie que le délai correspond à sleep 5 (±2 secondes)
4. ✅ Affiche baseline/expected time dans les findings

**Fichier corrigé :**
- `modules/vulnerability_tests/rce_module.sh` (lignes 98-127)

**Test :**
```bash
# Le test ne devrait plus détecter de faux positifs
# Seulement si le serveur répond vraiment 5 secondes plus tard
```

---

## Scripts de Correction

### fix_modules.sh

Script automatisé qui corrige :
- ✅ Erreurs grep (syntaxe)
- ✅ Exports XSS

**Usage :**
```bash
chmod +x fix_modules.sh
./fix_modules.sh
```

---

## Vérification Post-Correctifs

### Checklist

- [x] Erreurs grep corrigées dans 5 modules
- [x] Fonctions XSS exportées
- [x] Logique RCE time-based améliorée
- [x] Backups créés (.backup)
- [x] Tests effectués

### Tests Recommandés

```bash
# 1. Test autopilot basique
./leknight.sh
# Menu > Autopilot Mode > Start Autopilot

# 2. Vérifier qu'il n'y a plus d'erreurs grep
# (Regarder les logs pendant le scan)

# 3. Vérifier que XSS fonctionne
# (Doit voir les tests XSS sans erreurs "command not found")

# 4. Vérifier RCE time-based
# (Ne doit plus détecter de faux positifs sur tous les paramètres)
```

---

## Performance Impact

**Avant les corrections :**
- ❌ Erreurs grep à chaque test SSRF/SQLi/CSRF/IDOR/XSPA
- ❌ Tests XSS échouent silencieusement
- ❌ Dizaines de faux positifs RCE

**Après les corrections :**
- ✅ Aucune erreur grep
- ✅ Tests XSS fonctionnent
- ✅ Détection RCE précise (moins de faux positifs)

---

## Changelog v2.0.1

### Bugs Fixed
1. `grep -o "---HTTP_CODE"` syntax error
2. XSS functions not exported
3. RCE time-based false positives

### Files Modified
- `modules/vulnerability_tests/csrf_module.sh`
- `modules/vulnerability_tests/idor_module.sh`
- `modules/vulnerability_tests/sqli_module.sh`
- `modules/vulnerability_tests/ssrf_module.sh`
- `modules/vulnerability_tests/xspa_module.sh`
- `modules/vulnerability_tests/xss_module.sh`
- `modules/vulnerability_tests/rce_module.sh`

### Scripts Added
- `fix_modules.sh` - Automated fix script
- `BUGFIXES.md` - This file

---

## Support

Si vous rencontrez encore des problèmes :

1. **Vérifier que les corrections sont appliquées :**
   ```bash
   grep "grep -oE" modules/vulnerability_tests/ssrf_module.sh
   # Doit retourner des lignes avec "grep -oE"
   ```

2. **Réexécuter le script de correction :**
   ```bash
   ./fix_modules.sh
   ```

3. **Vérifier les backups :**
   ```bash
   ls modules/vulnerability_tests/*.backup
   # Si quelque chose ne va pas, restaurez depuis .backup
   ```

4. **Reporter le bug :**
   - GitHub Issues: https://github.com/YOUR_REPO/issues
   - Inclure les logs complets
   - Mentionner la version (v2.0.1)

---

## Leçons Apprises

1. **grep avec options :** Toujours utiliser `--` ou éviter les patterns commençant par `-`
2. **Exports bash :** Toutes les fonctions utilisées dans subshells doivent être exportées
3. **Time-based detection :** Toujours comparer au baseline, pas à un seuil absolu
4. **Testing :** Tester sur différents réseaux (lent, rapide, latence variable)

---

**Date :** 2025-11-10
**Version :** v2.0.1
**Status :** ✅ All bugs fixed and tested
