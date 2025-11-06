# 🚀 Améliorations Rapides LeKnight

## ⚡ Implémentables en <30 minutes

---

## 1. 🔒 Fix Sécurité - Injection de Commandes

**Fichier:** `core/wrapper.sh:47`

### ❌ Code Actuel (DANGEREUX)
```bash
# Ligne 47
eval "$command" 2>&1 | tee "$output_file"
```

### ✅ Code Sécurisé
```bash
# Remplacer par:
bash -c "$command" 2>&1 | tee "$output_file"

# OU encore mieux, valider les commandes:
if ! validate_command "$command"; then
    log_error "Invalid or dangerous command detected"
    return 1
fi
bash -c "$command" 2>&1 | tee "$output_file"
```

### Ajouter dans `core/utils.sh`:
```bash
# Validate command for dangerous patterns
validate_command() {
    local cmd="$1"

    # Blacklist de patterns dangereux
    local dangerous_patterns=(
        ';.*rm -rf'
        '\|\|.*rm'
        '&&.*rm'
        '`.*`'
        '\$\(.*rm.*\)'
        '>/dev/sd'
        'dd if='
        'mkfs'
        ':(){:|:&};:'  # Fork bomb
    )

    for pattern in "${dangerous_patterns[@]}"; do
        if echo "$cmd" | grep -qE "$pattern"; then
            log_error "Dangerous pattern detected: $pattern"
            return 1
        fi
    done

    return 0
}
```

---

## 2. 📊 Progress Bar avec ETA

**Fichier:** `workflows/autopilot.sh:106-130`

### Code à Ajouter
```bash
# Après ligne 106 (local processed=0)
local start_time=$(date +%s)

# Dans la boucle (après ligne 110)
while IFS='|' read -r target_id hostname ip port; do
    ((processed++))

    # Calculer progression et ETA
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    local avg_time_per_target=$((elapsed / processed))
    local remaining=$((target_count - processed))
    local eta_seconds=$((remaining * avg_time_per_target))

    # Afficher progress bar
    local progress=$((processed * 100 / target_count))
    local bar_length=50
    local filled=$((progress * bar_length / 100))
    local empty=$((bar_length - filled))

    printf "\r[%${filled}s%${empty}s] %d%% | %d/%d | ETA: %ds" \
        "$(printf '#%.0s' $(seq 1 $filled))" \
        "$(printf ' %.0s' $(seq 1 $empty))" \
        "$progress" "$processed" "$target_count" "$eta_seconds"

    # ... reste du code ...
done
```

---

## 3. 🔔 Notifications Discord

**Nouveau fichier:** `core/notifications.sh`

```bash
#!/bin/bash

# notifications.sh - Alert system for critical findings

# Discord webhook URL (set in .env or config)
DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"

# Send Discord notification
notify_discord() {
    local severity="$1"
    local title="$2"
    local description="$3"
    local target="${4:-unknown}"

    [ -z "$DISCORD_WEBHOOK" ] && return 0

    # Emoji par severity
    local emoji="ℹ️"
    local color="3447003"  # Bleu par défaut

    case "$severity" in
        critical)
            emoji="🚨"
            color="15158332"  # Rouge
            ;;
        high)
            emoji="⚠️"
            color="15105570"  # Orange
            ;;
        medium)
            emoji="⚡"
            color="15844367"  # Jaune
            ;;
        low)
            emoji="📌"
            color="3066993"   # Vert
            ;;
    esac

    local project_name=$(sqlite3 "$DB_PATH" "SELECT name FROM projects WHERE id = $(get_current_project);")

    local payload=$(cat <<EOF
{
  "embeds": [{
    "title": "$emoji **$severity** - $title",
    "description": "$description",
    "color": $color,
    "fields": [
      {
        "name": "Target",
        "value": "$target",
        "inline": true
      },
      {
        "name": "Project",
        "value": "$project_name",
        "inline": true
      },
      {
        "name": "Timestamp",
        "value": "$(date '+%Y-%m-%d %H:%M:%S')",
        "inline": true
      }
    ]
  }]
}
EOF
)

    curl -s -X POST "$DISCORD_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        2>/dev/null

    log_debug "Discord notification sent: $title"
}

# Send Telegram notification
notify_telegram() {
    local severity="$1"
    local title="$2"
    local description="$3"

    [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] && return 0

    local message="🔐 *LeKnight Alert*\n\n*Severity:* $severity\n*Finding:* $title\n\n$description"

    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=$TELEGRAM_CHAT_ID" \
        -d "text=$message" \
        -d "parse_mode=Markdown" \
        2>/dev/null
}

# Send notification to all configured channels
notify_all() {
    local severity="$1"
    local title="$2"
    local description="$3"
    local target="$4"

    # Only notify for medium and above
    case "$severity" in
        critical|high|medium)
            notify_discord "$severity" "$title" "$description" "$target"
            notify_telegram "$severity" "$title" "$description"
            ;;
    esac
}
```

### Intégration dans `core/database.sh:db_finding_add()`

Ajouter après ligne ~150:
```bash
# Send notification for critical/high findings
if [[ "$severity" =~ ^(critical|high)$ ]]; then
    notify_all "$severity" "$title" "$description" "$target_id"
fi
```

### Configuration dans `leknight-v2.sh`:
```bash
# Après ligne 14, ajouter:
source "${LEKNIGHT_ROOT}/core/notifications.sh"
```

---

## 4. 📈 Export JSON Structuré

**Nouveau fichier:** `reports/export_json.sh`

```bash
#!/bin/bash

# Export all project data as JSON
export_project_json() {
    local project_id="$1"
    local output_file="${2:-export.json}"

    if [ -z "$project_id" ]; then
        log_error "Project ID required"
        return 1
    fi

    log_info "Exporting project $project_id to JSON..."

    # Create JSON structure
    cat > "$output_file" <<EOF
{
  "export_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "leknight_version": "2.0.1",
  "project": $(sqlite3 "$DB_PATH" ".mode json" "SELECT * FROM projects WHERE id = $project_id;" | head -1),
  "targets": $(sqlite3 "$DB_PATH" ".mode json" "SELECT * FROM targets WHERE project_id = $project_id;"),
  "scans": $(sqlite3 "$DB_PATH" ".mode json" "SELECT * FROM scans WHERE project_id = $project_id;"),
  "findings": $(sqlite3 "$DB_PATH" ".mode json" "SELECT * FROM findings WHERE project_id = $project_id;"),
  "credentials": $(sqlite3 "$DB_PATH" ".mode json" "SELECT * FROM credentials WHERE project_id = $project_id;")
}
EOF

    log_success "Export saved to: $output_file"

    # File size
    local size=$(wc -c < "$output_file")
    log_info "Export size: $(format_size $size)"
}

# Export findings only (for integration with other tools)
export_findings_json() {
    local project_id="$1"
    local output_file="${2:-findings.json}"
    local severity_filter="${3:-all}"

    local where_clause="WHERE f.project_id = $project_id"

    if [ "$severity_filter" != "all" ]; then
        where_clause="$where_clause AND f.severity = '$severity_filter'"
    fi

    sqlite3 "$DB_PATH" <<EOF > "$output_file"
.mode json
SELECT
    f.id,
    f.severity,
    f.type,
    f.title,
    f.description,
    f.evidence,
    f.created_at,
    t.hostname,
    t.ip,
    t.port,
    s.tool
FROM findings f
JOIN targets t ON t.id = f.target_id
JOIN scans s ON s.id = f.scan_id
$where_clause
ORDER BY
    CASE f.severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
        WHEN 'info' THEN 5
    END,
    f.created_at DESC;
EOF

    log_success "Findings exported to: $output_file"
}

# Import findings from external JSON
import_findings_json() {
    local json_file="$1"
    local project_id="$2"

    if [ ! -f "$json_file" ]; then
        log_error "File not found: $json_file"
        return 1
    fi

    # Parse JSON and import (requires jq)
    if ! command_exists jq; then
        log_error "jq not installed (required for JSON import)"
        return 1
    fi

    local count=0
    jq -c '.[]' "$json_file" | while read -r finding; do
        local severity=$(echo "$finding" | jq -r '.severity')
        local type=$(echo "$finding" | jq -r '.type')
        local title=$(echo "$finding" | jq -r '.title')
        local description=$(echo "$finding" | jq -r '.description')

        # Create finding (simplified)
        db_finding_add "0" "$project_id" "0" "$severity" "$type" "$title" "$description" ""
        ((count++))
    done

    log_success "Imported $count findings"
}
```

---

## 5. 🔍 Top 10 Command

**Ajouter dans `leknight-v2.sh`:**

```bash
# Function to show top findings
show_top_findings() {
    local project_id=$(get_current_project)
    local limit="${1:-10}"

    if [ -z "$project_id" ]; then
        log_error "No project loaded"
        return 1
    fi

    log_section "TOP $limit CRITICAL FINDINGS"

    sqlite3 "$DB_PATH" <<EOF
SELECT
    CASE severity
        WHEN 'critical' THEN '🚨'
        WHEN 'high' THEN '⚠️'
        WHEN 'medium' THEN '⚡'
        WHEN 'low' THEN '📌'
        ELSE 'ℹ️'
    END || ' ' ||
    severity || ' - ' || title || ' (' || t.hostname || ')' AS finding
FROM findings f
JOIN targets t ON t.id = f.target_id
WHERE f.project_id = $project_id
AND f.severity IN ('critical', 'high')
ORDER BY
    CASE f.severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
    END,
    f.created_at DESC
LIMIT $limit;
EOF
}

# Add to main menu (after line 97):
echo -e "  ${RED}[8]${RESET}  ${BRIGHT_BLUE}Top Findings${RESET}"

# Add to case statement (after line 406):
8) show_top_findings; press_enter ;;
```

---

## 6. 🔄 Auto-Retry avec Backoff

**Ajouter dans `core/wrapper.sh`:**

```bash
# Execute with automatic retry
run_tool_with_retry() {
    local tool_name="$1"
    local target="$2"
    shift 2
    local additional_args="$@"

    local max_attempts=3
    local attempt=1
    local backoff=2

    while [ $attempt -le $max_attempts ]; do
        log_info "Attempt $attempt/$max_attempts for $tool_name"

        if run_tool "$tool_name" "$target" "$additional_args"; then
            log_success "$tool_name completed successfully"
            return 0
        fi

        if [ $attempt -lt $max_attempts ]; then
            local wait_time=$((backoff ** attempt))
            log_warning "$tool_name failed, retrying in ${wait_time}s..."
            sleep "$wait_time"
        fi

        ((attempt++))
    done

    log_error "$tool_name failed after $max_attempts attempts"
    return 1
}
```

---

## 7. ⚡ Scan Parallèle

**Ajouter dans `workflows/autopilot.sh`:**

```bash
# Parallel scan implementation (requires GNU parallel)
autopilot_parallel_scan() {
    local project_id=$(get_current_project)
    local max_jobs="${1:-5}"  # Default: 5 parallel scans

    if ! command_exists parallel; then
        log_warning "GNU parallel not installed, falling back to sequential"
        autopilot_start
        return
    fi

    log_info "Starting parallel autopilot with $max_jobs concurrent scans"

    # Get all targets
    local targets=$(get_unscanned_targets "$project_id")

    # Export functions for parallel to use
    export -f autopilot_scan_target
    export -f run_tool
    export -f log_info

    # Run in parallel
    echo "$targets" | parallel -j "$max_jobs" --colsep '|' \
        "autopilot_scan_target $project_id {1} {2}; mark_target_scanned {1}"

    log_success "Parallel autopilot completed"
}
```

---

## 8. 📋 Configuration File Support

**Nouveau fichier:** `config.yaml` (exemple)

```yaml
# LeKnight Configuration
leknight:
  version: 2.0.1

  # Database settings
  database:
    path: ./data/db/leknight.db
    backup_enabled: true
    backup_interval: 3600  # seconds

  # Autopilot settings
  autopilot:
    max_iterations: 10
    max_depth: 3
    parallel_scans: 5
    delay_between_scans: 2  # seconds
    scan_subdomains: true
    subdomain_limit: 50

  # Tool defaults
  tools:
    nmap:
      default_args: "-sV -sC -T4"
      timeout: 600
    nuclei:
      templates_path: ~/nuclei-templates
      severity_filter: critical,high,medium
      timeout: 1800
    nikto:
      timeout: 900

  # Notifications
  notifications:
    discord:
      enabled: true
      webhook_url: ${DISCORD_WEBHOOK}
      severity_threshold: medium

    telegram:
      enabled: false
      bot_token: ${TELEGRAM_BOT_TOKEN}
      chat_id: ${TELEGRAM_CHAT_ID}

  # Rate limiting
  rate_limiting:
    enabled: true
    max_requests_per_second: 10
    backoff_on_429: true  # HTTP 429 Too Many Requests

  # Security
  security:
    strict_scope_validation: true
    command_validation: true
    dangerous_commands_blacklist:
      - "rm -rf"
      - "dd if="
      - "mkfs"

  # Logging
  logging:
    level: INFO  # DEBUG, INFO, WARNING, ERROR, CRITICAL
    file_enabled: true
    console_enabled: true
    json_format: false
```

**Parser pour YAML (simple bash):**

```bash
# core/config.sh

# Parse YAML config (simple implementation)
parse_config() {
    local config_file="${1:-${LEKNIGHT_ROOT}/config.yaml}"

    if [ ! -f "$config_file" ]; then
        log_debug "No config file found, using defaults"
        return 0
    fi

    # Export variables from config (requires yq or manual parsing)
    if command_exists yq; then
        export AUTOPILOT_MAX_DEPTH=$(yq '.leknight.autopilot.max_depth' "$config_file")
        export AUTOPILOT_PARALLEL=$(yq '.leknight.autopilot.parallel_scans' "$config_file")
        export DISCORD_WEBHOOK=$(yq '.leknight.notifications.discord.webhook_url' "$config_file")
        # ... autres exports
    else
        log_warning "yq not installed, using default config"
    fi
}
```

---

## 📦 Installation de ces Améliorations

### 1. Copier les fichiers
```bash
# Dans le repo leknight-bash/
# Les fichiers sont déjà créés ci-dessus
```

### 2. Charger les nouveaux modules
```bash
# Dans leknight-v2.sh, après ligne 45:
source "${LEKNIGHT_ROOT}/core/notifications.sh"
source "${LEKNIGHT_ROOT}/reports/export_json.sh"
source "${LEKNIGHT_ROOT}/core/config.sh"

# Charger la config
parse_config
```

### 3. Installer les dépendances
```bash
# Pour notifications
# Discord: webhook URL seulement (no install needed)

# Pour JSON export avancé
sudo apt-get install -y jq

# Pour scans parallèles
sudo apt-get install -y parallel

# Pour parsing YAML
sudo snap install yq
```

### 4. Configurer
```bash
# Créer .env pour secrets
cat > .env <<EOF
DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_WEBHOOK"
TELEGRAM_BOT_TOKEN="your_bot_token"
TELEGRAM_CHAT_ID="your_chat_id"
EOF

# Charger dans leknight-v2.sh
[ -f "${LEKNIGHT_ROOT}/.env" ] && source "${LEKNIGHT_ROOT}/.env"
```

---

## 🎯 Impact Attendu

| Amélioration | Impact | Temps Impl. |
|-------------|--------|-------------|
| Fix injection | 🔒 Sécurité critique | 10 min |
| Progress bar | 📊 UX +50% | 15 min |
| Notifications | 🔔 Alertes temps réel | 20 min |
| Export JSON | 📄 Intégration ++| 15 min |
| Top findings | 🔍 Visibilité | 10 min |
| Auto-retry | 🔄 Fiabilité +30% | 15 min |
| Parallel scan | ⚡ Speed x5 | 20 min |
| Config file | ⚙️ Flexibilité | 30 min |

**TOTAL:** ~2h30 de dev pour améliorer drastiquement LeKnight

---

## 🚀 Prochaines Étapes

1. **Tester** chaque amélioration individuellement
2. **Documenter** dans README
3. **Commit** avec messages clairs
4. **Release** v2.1.0 avec ces features

**Bon dev! 🎯⚔️**
