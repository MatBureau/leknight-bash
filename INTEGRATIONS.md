# 🔗 Intégrations LeKnight

Guide pour intégrer LeKnight avec d'autres outils de bug bounty et pentest.

---

## 📡 Intégrations Disponibles

### 1. **Burp Suite** - Import de Scopes & Targets
### 2. **Nuclei** - Templates personnalisés
### 3. **Metasploit** - Export pour exploitation
### 4. **Shodan** - Enrichissement de données
### 5. **TheHive** - Case management
### 6. **Jira** - Ticket automation
### 7. **CI/CD** - GitHub Actions, GitLab CI
### 8. **SIEM** - Splunk, ELK Stack

---

## 🎯 1. Burp Suite Integration

### A. Importer le Scope de Burp dans LeKnight

```bash
#!/bin/bash
# burp_to_leknight.sh

# Export scope from Burp: Target > Scope > Save
BURP_SCOPE_FILE="$1"
PROJECT_ID="$2"

if [ ! -f "$BURP_SCOPE_FILE" ]; then
    echo "Usage: $0 <burp_scope.json> <project_id>"
    exit 1
fi

# Parse Burp scope (JSON format)
jq -r '.target.scope.include[] | select(.enabled==true) | .host' "$BURP_SCOPE_FILE" | \
while read -r target; do
    echo "Adding target: $target"
    ./leknight-v2.sh project add-target "$PROJECT_ID" "$target"
done

echo "Scope imported successfully"
```

### B. Exporter les Findings LeKnight vers Burp

```bash
# leknight_to_burp.sh

PROJECT_ID="$1"
OUTPUT_FILE="burp_import_${PROJECT_ID}.xml"

sqlite3 "$DB_PATH" <<EOF > "$OUTPUT_FILE"
<?xml version="1.0"?>
<issues burpVersion="2023.11">
$(
SELECT
    '<issue>
        <serialNumber>' || f.id || '</serialNumber>
        <type>0x' || printf('%08x', f.id) || '</type>
        <name>' || f.title || '</name>
        <host>' || COALESCE(t.hostname, t.ip) || '</host>
        <path>/</path>
        <location>' || COALESCE(t.hostname, t.ip) || '</location>
        <severity>' ||
            CASE f.severity
                WHEN 'critical' THEN 'High'
                WHEN 'high' THEN 'High'
                WHEN 'medium' THEN 'Medium'
                WHEN 'low' THEN 'Low'
                ELSE 'Information'
            END ||
        '</severity>
        <confidence>Certain</confidence>
        <issueBackground>' || f.description || '</issueBackground>
        <issueDetail>' || f.evidence || '</issueDetail>
    </issue>'
FROM findings f
JOIN targets t ON t.id = f.target_id
WHERE f.project_id = $PROJECT_ID
)
</issues>
EOF

echo "Burp XML saved to: $OUTPUT_FILE"
echo "Import in Burp: Target > Site map > Right-click > Import"
```

---

## 🔬 2. Nuclei Templates Personnalisés

### A. Créer des Templates depuis Findings

```bash
# generate_nuclei_template.sh

FINDING_ID="$1"

# Get finding details
FINDING=$(sqlite3 "$DB_PATH" "SELECT title, description, evidence FROM findings WHERE id = $FINDING_ID;")

TITLE=$(echo "$FINDING" | cut -d'|' -f1)
DESCRIPTION=$(echo "$FINDING" | cut -d'|' -f2)
EVIDENCE=$(echo "$FINDING" | cut -d'|' -f3)

# Extract URL/path from evidence
URL=$(echo "$EVIDENCE" | grep -oE 'https?://[^ ]+' | head -1)

cat > "nuclei-templates/custom-${FINDING_ID}.yaml" <<EOF
id: leknight-custom-${FINDING_ID}

info:
  name: ${TITLE}
  author: leknight-autopilot
  severity: high
  description: |
    ${DESCRIPTION}
  reference:
    - LeKnight Finding ID: ${FINDING_ID}

requests:
  - method: GET
    path:
      - "{{BaseURL}}${URL#*://*/}"

    matchers-condition: and
    matchers:
      - type: word
        words:
          - "vulnerable"
        part: body

      - type: status
        status:
          - 200
EOF

echo "Template created: nuclei-templates/custom-${FINDING_ID}.yaml"
```

### B. Scanner avec Templates Personnalisés

```bash
# Ajouter dans workflows/web_recon.sh

# STEP: Custom Nuclei Templates
if [ -d "${LEKNIGHT_ROOT}/nuclei-templates/custom" ]; then
    log_info "Running custom Nuclei templates..."
    run_tool "nuclei" "$target" "-t ${LEKNIGHT_ROOT}/nuclei-templates/custom/"
fi
```

---

## 🎮 3. Metasploit Integration

### A. Export vers Format Metasploit

```bash
#!/bin/bash
# leknight_to_msf.sh

PROJECT_ID="$1"
OUTPUT_RC="autopwn_${PROJECT_ID}.rc"

echo "# LeKnight to Metasploit Resource Script" > "$OUTPUT_RC"
echo "# Project ID: $PROJECT_ID" >> "$OUTPUT_RC"
echo "# Generated: $(date)" >> "$OUTPUT_RC"
echo "" >> "$OUTPUT_RC"

# Get vulnerable targets
sqlite3 "$DB_PATH" <<EOF | while IFS='|' read -r ip port service vuln_type; do
SELECT DISTINCT
    COALESCE(t.ip, '0.0.0.0'),
    COALESCE(t.port, 0),
    COALESCE(t.service, 'unknown'),
    f.type
FROM findings f
JOIN targets t ON t.id = f.target_id
WHERE f.project_id = $PROJECT_ID
AND f.severity IN ('critical', 'high')
AND f.type IN ('rce', 'sql-injection', 'file-upload', 'command-injection');
EOF

    # Map vulnerability types to Metasploit modules
    case "$vuln_type" in
        sql-injection)
            cat >> "$OUTPUT_RC" <<MSFEXIT
use auxiliary/scanner/http/sql_injection
set RHOSTS $ip
set RPORT $port
run
MSFEXIT
            ;;
        rce|command-injection)
            cat >> "$OUTPUT_RC" <<MSFEXIT
use exploit/multi/http/command_injection
set RHOSTS $ip
set RPORT $port
set LHOST 10.0.0.1
check
exploit
MSFEXIT
            ;;
    esac
done

echo "Metasploit resource script created: $OUTPUT_RC"
echo "Usage: msfconsole -r $OUTPUT_RC"
```

### B. Importer Résultats Metasploit

```bash
# msf_to_leknight.sh

MSF_DB_EXPORT="$1"  # Export from: db_export -f json
PROJECT_ID="$2"

jq -c '.hosts[]' "$MSF_DB_EXPORT" | while read -r host; do
    IP=$(echo "$host" | jq -r '.address')
    OS=$(echo "$host" | jq -r '.os_name')

    # Add target
    TARGET_ID=$(./leknight-v2.sh project add-target "$PROJECT_ID" "$IP")

    # Add OS finding
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO findings (project_id, target_id, severity, type, title, description)
VALUES ($PROJECT_ID, $TARGET_ID, 'info', 'os-detection', 'OS: $OS', 'Detected by Metasploit');
EOF

    # Import services
    echo "$host" | jq -c '.services[]' | while read -r service; do
        PORT=$(echo "$service" | jq -r '.port')
        NAME=$(echo "$service" | jq -r '.name')

        echo "Service: $IP:$PORT ($NAME)"
    done
done
```

---

## 🌐 4. Shodan API Integration

### A. Enrichir les Targets avec Shodan

```bash
#!/bin/bash
# shodan_enrich.sh

SHODAN_API_KEY="${SHODAN_API_KEY}"
PROJECT_ID="$1"

if [ -z "$SHODAN_API_KEY" ]; then
    echo "Set SHODAN_API_KEY environment variable"
    exit 1
fi

# Get all IPs from project
sqlite3 "$DB_PATH" "SELECT DISTINCT ip FROM targets WHERE project_id = $PROJECT_ID AND ip IS NOT NULL;" | \
while read -r ip; do
    echo "Enriching $ip with Shodan data..."

    # Query Shodan API
    SHODAN_DATA=$(curl -s "https://api.shodan.io/shodan/host/${ip}?key=${SHODAN_API_KEY}")

    # Extract interesting data
    ORG=$(echo "$SHODAN_DATA" | jq -r '.org // "unknown"')
    ISP=$(echo "$SHODAN_DATA" | jq -r '.isp // "unknown"')
    COUNTRY=$(echo "$SHODAN_DATA" | jq -r '.country_name // "unknown"')
    VULNS=$(echo "$SHODAN_DATA" | jq -r '.vulns[] // empty' | tr '\n' ',')

    # Store in database
    TARGET_ID=$(sqlite3 "$DB_PATH" "SELECT id FROM targets WHERE project_id = $PROJECT_ID AND ip = '$ip' LIMIT 1;")

    # Add enrichment finding
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO findings (project_id, target_id, severity, type, title, description)
VALUES (
    $PROJECT_ID,
    $TARGET_ID,
    'info',
    'shodan-enrichment',
    'Shodan Intelligence',
    'Organization: $ORG\nISP: $ISP\nCountry: $COUNTRY\nVulns: $VULNS'
);
EOF

    echo "  ✓ Enriched with Shodan data"

    # Rate limiting (Shodan free tier: 1 req/sec)
    sleep 1
done

echo "Shodan enrichment completed"
```

### B. Auto-Discover Targets via Shodan

```bash
# shodan_discover.sh

QUERY="$1"  # e.g., "org:Tesla ssl:expired"
PROJECT_ID="$2"

curl -s "https://api.shodan.io/shodan/host/search?key=${SHODAN_API_KEY}&query=${QUERY}" | \
jq -r '.matches[].ip_str' | while read -r ip; do
    echo "Discovered: $ip"
    ./leknight-v2.sh project add-target "$PROJECT_ID" "$ip"
done
```

---

## 📊 5. TheHive Case Management

### A. Créer des Cases Automatiquement

```bash
#!/bin/bash
# leknight_to_thehive.sh

THEHIVE_URL="http://thehive.local:9000"
THEHIVE_API_KEY="${THEHIVE_API_KEY}"
PROJECT_ID="$1"

# Get critical findings
sqlite3 "$DB_PATH" <<EOF | while IFS='|' read -r title severity description target; do
SELECT f.title, f.severity, f.description, COALESCE(t.hostname, t.ip)
FROM findings f
JOIN targets t ON t.id = f.target_id
WHERE f.project_id = $PROJECT_ID
AND f.severity IN ('critical', 'high')
AND f.created_at >= datetime('now', '-1 day');
EOF

    # Create case in TheHive
    CASE_JSON=$(cat <<JSON
{
  "title": "$title",
  "description": "$description",
  "severity": 2,
  "tlp": 2,
  "tags": ["leknight", "autopilot", "$severity"],
  "customFields": {
    "target": {
      "string": "$target"
    }
  }
}
JSON
)

    RESPONSE=$(curl -s -X POST "$THEHIVE_URL/api/case" \
        -H "Authorization: Bearer $THEHIVE_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$CASE_JSON")

    CASE_ID=$(echo "$RESPONSE" | jq -r '.id')
    echo "Created case: $CASE_ID for $title"
done
```

---

## 🎫 6. Jira Integration

### A. Créer des Tickets Automatiquement

```bash
#!/bin/bash
# leknight_to_jira.sh

JIRA_URL="https://your-company.atlassian.net"
JIRA_USER="${JIRA_USER}"
JIRA_API_TOKEN="${JIRA_API_TOKEN}"
JIRA_PROJECT="SEC"  # Security project key

PROJECT_ID="$1"

# Get high/critical findings
sqlite3 "$DB_PATH" <<EOF | while IFS='|' read -r id title severity description target; do
SELECT f.id, f.title, f.severity, f.description, COALESCE(t.hostname, t.ip)
FROM findings f
JOIN targets t ON t.id = f.target_id
WHERE f.project_id = $PROJECT_ID
AND f.severity IN ('critical', 'high')
AND NOT EXISTS (
    SELECT 1 FROM findings WHERE id = f.id AND description LIKE '%JIRA:%'
);
EOF

    # Determine priority
    PRIORITY="High"
    [ "$severity" = "critical" ] && PRIORITY="Highest"

    # Create Jira issue
    ISSUE_JSON=$(cat <<JSON
{
  "fields": {
    "project": {
      "key": "$JIRA_PROJECT"
    },
    "summary": "$title",
    "description": "Target: $target\n\nSeverity: $severity\n\n$description\n\nLeKnight Finding ID: $id",
    "issuetype": {
      "name": "Bug"
    },
    "priority": {
      "name": "$PRIORITY"
    },
    "labels": ["leknight", "security", "$severity"]
  }
}
JSON
)

    RESPONSE=$(curl -s -u "$JIRA_USER:$JIRA_API_TOKEN" \
        -X POST "$JIRA_URL/rest/api/2/issue" \
        -H "Content-Type: application/json" \
        -d "$ISSUE_JSON")

    ISSUE_KEY=$(echo "$RESPONSE" | jq -r '.key')

    # Update finding with Jira reference
    sqlite3 "$DB_PATH" <<SQL
UPDATE findings
SET description = description || '\n\nJIRA: $ISSUE_KEY'
WHERE id = $id;
SQL

    echo "Created Jira issue: $ISSUE_KEY for finding $id"
done
```

---

## 🤖 7. GitHub Actions CI/CD

### Workflow: Scan on PR

```yaml
# .github/workflows/security-scan.yml
name: LeKnight Security Scan

on:
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM

jobs:
  security-scan:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Install LeKnight
        run: |
          git clone https://github.com/YOUR-ORG/leknight-bash.git
          cd leknight-bash
          chmod +x leknight-v2.sh setup.sh
          sudo ./setup.sh

      - name: Create project
        run: |
          cd leknight-bash
          PROJECT_ID=$(./leknight-v2.sh project create "CI-Scan-${{ github.run_id }}" "Automated security scan" "staging.example.com")
          echo "PROJECT_ID=$PROJECT_ID" >> $GITHUB_ENV

      - name: Run autopilot
        run: |
          cd leknight-bash
          ./leknight-v2.sh autopilot start --project-id ${{ env.PROJECT_ID }}

      - name: Export findings
        run: |
          cd leknight-bash
          ./leknight-v2.sh export json findings.json --project-id ${{ env.PROJECT_ID }}

      - name: Check for critical findings
        run: |
          cd leknight-bash
          CRITICAL_COUNT=$(sqlite3 data/db/leknight.db "SELECT COUNT(*) FROM findings WHERE project_id = ${{ env.PROJECT_ID }} AND severity = 'critical';")
          echo "Critical findings: $CRITICAL_COUNT"

          if [ "$CRITICAL_COUNT" -gt 0 ]; then
            echo "::error::Found $CRITICAL_COUNT critical security issues!"
            exit 1
          fi

      - name: Upload findings as artifact
        uses: actions/upload-artifact@v3
        with:
          name: security-findings
          path: leknight-bash/findings.json

      - name: Comment on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const findings = JSON.parse(fs.readFileSync('leknight-bash/findings.json', 'utf8'));

            let comment = '## 🔒 Security Scan Results\n\n';
            comment += `- Total findings: ${findings.length}\n`;

            const bySeverity = findings.reduce((acc, f) => {
              acc[f.severity] = (acc[f.severity] || 0) + 1;
              return acc;
            }, {});

            for (const [severity, count] of Object.entries(bySeverity)) {
              comment += `- ${severity}: ${count}\n`;
            }

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });
```

### Workflow: Scheduled Scan

```yaml
# .github/workflows/weekly-scan.yml
name: Weekly Security Scan

on:
  schedule:
    - cron: '0 3 * * 0'  # Sundays at 3 AM

jobs:
  weekly-scan:
    runs-on: ubuntu-latest

    steps:
      - name: Install LeKnight
        run: |
          git clone https://github.com/YOUR-ORG/leknight-bash.git
          cd leknight-bash && ./setup.sh

      - name: Run full scan
        env:
          DISCORD_WEBHOOK: ${{ secrets.DISCORD_WEBHOOK }}
        run: |
          cd leknight-bash
          ./leknight-v2.sh project create "Weekly-Scan-$(date +%Y%m%d)" "Scheduled scan" "*.example.com"
          ./leknight-v2.sh autopilot start --depth deep

      - name: Generate report
        run: |
          cd leknight-bash
          ./leknight-v2.sh report generate --format markdown

      - name: Send to Discord
        run: |
          # Report summary sent via webhook
```

---

## 📡 8. ELK Stack / Splunk Integration

### A. Export Logs to Elasticsearch

```bash
#!/bin/bash
# leknight_to_elasticsearch.sh

ES_URL="${ES_URL:-http://localhost:9200}"
ES_INDEX="leknight-findings"
PROJECT_ID="$1"

# Create index if not exists
curl -X PUT "$ES_URL/$ES_INDEX" -H 'Content-Type: application/json' -d '{
  "mappings": {
    "properties": {
      "timestamp": { "type": "date" },
      "severity": { "type": "keyword" },
      "title": { "type": "text" },
      "target": { "type": "keyword" },
      "project_id": { "type": "integer" }
    }
  }
}'

# Export findings to ES
sqlite3 "$DB_PATH" -json <<EOF | while read -r line; do
SELECT
    f.created_at as timestamp,
    f.severity,
    f.type,
    f.title,
    f.description,
    COALESCE(t.hostname, t.ip) as target,
    f.project_id
FROM findings f
JOIN targets t ON t.id = f.target_id
WHERE f.project_id = $PROJECT_ID;
EOF

    curl -X POST "$ES_URL/$ES_INDEX/_doc" \
        -H 'Content-Type: application/json' \
        -d "$line"
done

echo "Findings exported to Elasticsearch"
```

### B. Kibana Dashboard

```json
{
  "title": "LeKnight Security Dashboard",
  "visualizations": [
    {
      "title": "Findings by Severity",
      "type": "pie",
      "field": "severity"
    },
    {
      "title": "Findings Timeline",
      "type": "line",
      "x_axis": "timestamp",
      "y_axis": "count"
    },
    {
      "title": "Top Vulnerable Targets",
      "type": "bar",
      "field": "target"
    }
  ]
}
```

---

## 🔐 9. HackerOne / Bugcrowd Export

### Format de Rapport Compatible

```bash
#!/bin/bash
# export_bug_bounty_report.sh

FINDING_ID="$1"
OUTPUT_FILE="report_${FINDING_ID}.md"

# Get finding details
FINDING=$(sqlite3 "$DB_PATH" <<EOF
SELECT
    f.severity,
    f.type,
    f.title,
    f.description,
    f.evidence,
    COALESCE(t.hostname, t.ip) as target,
    p.name as project
FROM findings f
JOIN targets t ON t.id = f.target_id
JOIN projects p ON p.id = f.project_id
WHERE f.id = $FINDING_ID;
EOF
)

IFS='|' read -r severity type title description evidence target project <<< "$FINDING"

# Generate bug bounty report
cat > "$OUTPUT_FILE" <<EOF
# $title

## Summary
$description

## Severity
**$severity**

## Target
- **Asset:** $target
- **Project:** $project

## Steps to Reproduce

1. Navigate to: $target
2. [Add manual steps here]
3. Observe the vulnerability

## Proof of Concept

\`\`\`
$evidence
\`\`\`

## Impact

[Describe the impact of this vulnerability]

## Remediation

[Suggest fixes]

## References

- LeKnight Finding ID: $FINDING_ID
- Date Discovered: $(date)

---

**Discovered by LeKnight Autopilot v2.0**
EOF

echo "Bug bounty report generated: $OUTPUT_FILE"
```

---

## 📧 10. Email Alerts

### Configuration

```bash
# core/notifications.sh (add email function)

send_email_alert() {
    local to_email="${ALERT_EMAIL}"
    local subject="$1"
    local body="$2"

    [ -z "$to_email" ] && return 0

    # Using sendmail or mailx
    if command_exists mail; then
        echo "$body" | mail -s "$subject" "$to_email"
    elif command_exists sendmail; then
        {
            echo "To: $to_email"
            echo "Subject: $subject"
            echo ""
            echo "$body"
        } | sendmail -t
    else
        log_warning "No mail client found, skipping email alert"
    fi
}
```

---

## 🎯 Intégration Complète: Pipeline de Bug Bounty

### Workflow Complet

```bash
#!/bin/bash
# bug_bounty_pipeline.sh

PROJECT_NAME="$1"
SCOPE="$2"

echo "🚀 Starting Bug Bounty Pipeline"

# 1. Create project
echo "📁 Creating project..."
PROJECT_ID=$(./leknight-v2.sh project create "$PROJECT_NAME" "Bug bounty engagement" "$SCOPE")

# 2. Enrich with Shodan
echo "🌐 Enriching with Shodan..."
./integrations/shodan_enrich.sh "$PROJECT_ID"

# 3. Run autopilot
echo "🤖 Starting autopilot..."
./leknight-v2.sh autopilot start --project-id "$PROJECT_ID"

# 4. Export findings
echo "📊 Exporting findings..."
./leknight-v2.sh export json findings.json --project-id "$PROJECT_ID"

# 5. Create Jira tickets
echo "🎫 Creating Jira tickets..."
./integrations/leknight_to_jira.sh "$PROJECT_ID"

# 6. Generate reports
echo "📄 Generating reports..."
./leknight-v2.sh report generate --format markdown

# 7. Send notifications
echo "🔔 Sending notifications..."
./integrations/notify_discord.sh "$PROJECT_ID"

echo "✅ Pipeline completed!"
```

---

**Bon hunting! 🎯🔍**
