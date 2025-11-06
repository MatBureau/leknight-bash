# LeKnight - Roadmap d'Amélioration

## 🎯 Vision
Transformer LeKnight en framework de pentest autonome de niveau entreprise, capable de rivaliser avec des outils commerciaux.

---

## 🔥 Priorité CRITIQUE (v2.1.0)

### 1. Sécurité - Éliminer les Risques d'Injection
**Problème:** `eval "$command"` dans wrapper.sh:47 = injection de commandes possible
**Impact:** Sécurité critique
**Solution:**
```bash
# AVANT (DANGEREUX):
eval "$command" 2>&1 | tee "$output_file"

# APRÈS (SÉCURISÉ):
bash -c "$command" 2>&1 | tee "$output_file"
# OU mieux: construire un array et exécuter directement
```

### 2. Validation de Scope Stricte
**Problème:** Aucune validation que les cibles découvertes sont dans le scope
**Impact:** Risque légal majeur
**Solution:**
- Fonction `is_in_scope()` qui vérifie TOUTES les nouvelles cibles
- Bloquer l'autopilot si sortie de scope
- Logs d'audit de toutes les tentatives hors scope

### 3. Parallélisation des Scans
**Problème:** Tout est séquentiel = lent sur gros projets
**Impact:** Performance x10 possible
**Solution:**
```bash
# Lancer 5 scans en parallèle avec GNU parallel
parallel -j 5 run_tool ::: nmap nikto nuclei subfinder whatweb
```

### 4. Rate Limiting & Politeness
**Problème:** Risque de bannissement IP, DOS involontaire
**Impact:** Stabilité des scans
**Solution:**
- Délais configurables entre requêtes
- Detection automatique de rate limiting (HTTP 429)
- Backoff exponentiel en cas d'erreur
- User-Agent randomisé

---

## ⚡ Priorité HAUTE (v2.2.0)

### 5. Système de Notifications
**Fonctionnalité:** Alertes temps réel pour findings critiques
**Outils:** Discord, Slack, Telegram, Email
**Exemple:**
```bash
# Envoyer notification Discord quand SQL injection trouvée
notify_discord() {
    local webhook_url="$DISCORD_WEBHOOK"
    local severity="$1"
    local title="$2"

    curl -X POST "$webhook_url" \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"🚨 **$severity** - $title\"}"
}
```

### 6. Retry Logic & Resilience
**Problème:** Échecs réseau font échouer tout le scan
**Solution:**
- 3 tentatives automatiques avec backoff
- Sauvegarde de l'état pour reprise
- `resume_failed_scans()` amélioré

### 7. Parsers Avancés
**Améliorations:**
- **CVE Extraction:** Normaliser tous les CVE-XXXX-XXXXX trouvés
- **CVSS Scoring:** Intégrer scores de gravité officiels
- **Masscan Parser:** Actuellement non parsé
- **Gowitness Parser:** Extraire screenshot metadata
- **JSON Output:** Tous les outils en JSON quand possible

### 8. Configuration Centralisée
**Problème:** Tout hardcodé, difficile à personnaliser
**Solution:**
```yaml
# config.yaml
leknight:
  database:
    path: ./data/db/leknight.db
    backup_interval: 3600

  autopilot:
    max_depth: 3
    parallel_scans: 5
    delay_between_scans: 2

  notifications:
    discord:
      enabled: true
      webhook: $DISCORD_WEBHOOK
      severity_threshold: high

  tools:
    nmap:
      default_args: "-sV -sC -T4"
      timeout: 600
    nuclei:
      templates: /path/to/templates
      severity: critical,high,medium
```

---

## 🚀 Priorité MOYENNE (v2.3.0)

### 9. Diff Mode - Quoi de Nouveau?
**Fonctionnalité:** Comparer 2 scans pour voir les changements
**Cas d'usage:**
- "Quels nouveaux ports ouverts depuis hier?"
- "Nouvelles vulnérabilités apparues?"
- "Nouveaux subdomains découverts?"

**Implémentation:**
```bash
leknight diff <scan_id_old> <scan_id_new>

# Output:
[+] New findings:
    - SQL injection on /login.php
    - Port 8080 now open
[-] Resolved:
    - XSS on /search.php (now patched)
```

### 10. Intelligence Artificielle - ML pour Faux Positifs
**Problème:** Beaucoup de false positives (surtout Nikto)
**Solution:**
- Classifier basé sur historique
- Confiance score pour chaque finding
- Apprentissage: "marquer comme faux positif"

### 11. Dashboard Web
**Technologie:** HTML/CSS/JS statique ou Flask léger
**Fonctionnalités:**
- Vue temps réel de l'autopilot
- Graphiques de progression
- Heatmap des cibles
- Timeline des découvertes

### 12. API REST
**Endpoints:**
```
GET  /api/projects
POST /api/projects
GET  /api/projects/{id}/targets
POST /api/projects/{id}/autopilot/start
GET  /api/findings?severity=critical
```

### 13. Priorisation Intelligente des Cibles
**Heuristiques:**
- Privilégier les cibles avec ports web ouverts
- Scanner d'abord les IPs avec plus de services
- Rescanner automatiquement les cibles avec findings critiques
- Éviter de rescanner les cibles "mortes" (pas de réponse)

---

## 📊 Priorité BASSE (v3.0.0)

### 14. TUI Moderne (Terminal UI)
**Remplacer:** Le menu actuel par interface Rich/Textual
**Inspiration:** Lazygit, K9s
**Fonctionnalités:**
- Split panels (logs | status | findings)
- Search/filter en temps réel
- Vim keybindings

### 15. Exploitation Automatique Avancée
**Extension du `exploit_mode`:**
- Intégration Metasploit API
- Génération de payloads adaptés
- Post-exploitation automatique
- Pivoting automatique

### 16. Fuzzing Intégré
**Outils:** ffuf, wfuzz avec wordlists intelligentes
**Features:**
- Fuzzing de paramètres découverts
- Fuzzing de headers
- Detection automatique d'injection points

### 17. Compliance Checks
**Frameworks:** OWASP Top 10, PCI-DSS, ISO 27001
**Output:**
```
[✓] OWASP-A01: Passed (no injection found)
[✗] OWASP-A02: Failed (weak authentication)
[✓] OWASP-A03: Passed (encryption enforced)
```

### 18. Collaboration Multi-Utilisateur
**Fonctionnalités:**
- Plusieurs pentester sur même projet
- Lock de cibles pour éviter double scan
- Comments sur findings
- Assignment de tasks

### 19. Intégration CI/CD
**Exemples:**
```yaml
# .github/workflows/security-scan.yml
- name: LeKnight Scan
  run: |
    leknight project create "CI Scan"
    leknight autopilot start
    leknight export findings.json

- name: Fail if Critical
  run: |
    if leknight findings --severity critical --count > 0; then
      exit 1
    fi
```

---

## 🛠️ Améliorations Techniques

### Code Quality
- [ ] **Tests unitaires** avec BATS (Bash Automated Testing System)
- [ ] **Linting** avec ShellCheck
- [ ] **Documentation** de toutes les fonctions (docstrings)
- [ ] **Refactoring** des fonctions >100 lignes
- [ ] **Error handling** systématique (set -euo pipefail)

### Database
- [ ] **Migration automatique** des schémas
- [ ] **Indexes** sur toutes les foreign keys
- [ ] **Backup automatique** toutes les heures
- [ ] **Compression** des vieux scans (>30 jours)
- [ ] **RelationsMany-to-Many** pour CVEs

### Performance
- [ ] **Cache DNS** pour éviter lookups répétés
- [ ] **Connection pooling** pour DB
- [ ] **Lazy loading** des gros outputs
- [ ] **Pagination** des résultats

### Observability
- [ ] **Métriques Prometheus** (scan_duration, success_rate, etc.)
- [ ] **Structured logging** (JSON logs)
- [ ] **Distributed tracing** (pour comprendre les lenteurs)
- [ ] **Healthcheck endpoint** pour monitoring

---

## 📈 Implémentation Recommandée

### Phase 1: Stabilité (v2.1.0 - 2 semaines)
1. Fix eval injection
2. Scope validation
3. Retry logic
4. Configuration YAML

### Phase 2: Performance (v2.2.0 - 3 semaines)
1. Parallélisation
2. Rate limiting
3. Parsers avancés
4. Notifications

### Phase 3: Intelligence (v2.3.0 - 1 mois)
1. Diff mode
2. ML faux positifs
3. Priorisation
4. Dashboard web

### Phase 4: Entreprise (v3.0.0 - 2 mois)
1. API REST
2. TUI moderne
3. Collaboration
4. CI/CD integration

---

## 🎯 Quick Wins (Implémentable en <1 jour)

### 1. Progress Bar
```bash
# Ajouter dans workflow
for i in $(seq 1 $total_steps); do
    echo -ne "Progress: [$i/$total_steps] $(($i * 100 / $total_steps))%\r"
done
```

### 2. Temps Restant Estimé
```bash
# Calculer vitesse moyenne et estimer
remaining=$((total_targets - processed))
avg_time=$((elapsed / processed))
eta=$((remaining * avg_time))
echo "ETA: $(date -d @$eta)"
```

### 3. Export JSON Findings
```bash
export_findings_json() {
    sqlite3 "$DB_PATH" <<EOF
.mode json
SELECT * FROM findings WHERE project_id = $1;
EOF
}
```

### 4. Top 10 Findings
```bash
leknight top

# Output:
Top 10 Most Critical Findings:
1. SQL Injection on /login.php (CVSS: 9.8)
2. RCE via file upload (CVSS: 9.6)
3. Weak admin credentials (CVSS: 8.5)
...
```

### 5. Auto-Install Missing Tools
```bash
check_and_install_tool() {
    local tool="$1"

    if ! command_exists "$tool"; then
        log_warning "$tool not installed"
        if confirm "Install $tool now?"; then
            sudo apt-get install -y "$tool"
        fi
    fi
}
```

---

## 📚 Ressources

### Outils à Intégrer
- **Amass** - Meilleur que subfinder pour DNS
- **httpx** - Vérifier quels domaines sont alive
- **Katana** - Web crawler (ProjectDiscovery)
- **Gau** - Get All URLs from Wayback/AlienVault
- **Dalfox** - XSS scanner
- **Gf** - Grep patterns pour findings
- **Anew** - Déduplications intelligentes

### Wordlists
- SecLists (30GB)
- Assetnote wordlists
- OneListForAll

### APIs Utiles
- **Shodan** - Enrichissement de targets
- **VirusTotal** - Reputation check
- **HaveIBeenPwned** - Credential check
- **CVE API** - Info sur CVEs
- **Exploit-DB API** - Exploits disponibles

---

## 🤝 Contributions Attendues

### Issues GitHub
- [ ] Template pour bug reports
- [ ] Template pour feature requests
- [ ] Labels (bug, enhancement, good-first-issue)

### Documentation
- [ ] Architecture diagram
- [ ] Database schema diagram
- [ ] Contributing guide
- [ ] Code of conduct

### Community
- [ ] Discord server pour support
- [ ] Blog posts de use cases
- [ ] YouTube tutorials

---

**Prochaine action recommandée:** Implémenter les Quick Wins + Phase 1 pour v2.1.0
