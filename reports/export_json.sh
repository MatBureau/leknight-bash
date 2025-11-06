#!/bin/bash

# export_json.sh - Advanced JSON export functionality
# Export findings, projects, and full database dumps in JSON format

# Export complete project data as JSON
export_project_json() {
    local project_id="$1"
    local output_file="${2:-export_project_${project_id}.json}"

    if [ -z "$project_id" ]; then
        log_error "Project ID required"
        return 1
    fi

    log_info "Exporting project $project_id to JSON..."

    # Check if project exists
    local project_exists=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM projects WHERE id = $project_id;")
    if [ "$project_exists" -eq 0 ]; then
        log_error "Project ID $project_id not found"
        return 1
    fi

    # Create temporary files for each section
    local tmp_dir="/tmp/leknight_export_$$"
    mkdir -p "$tmp_dir"

    # Export each section
    sqlite3 "$DB_PATH" <<EOF > "${tmp_dir}/project.json"
.mode json
SELECT * FROM projects WHERE id = $project_id;
EOF

    sqlite3 "$DB_PATH" <<EOF > "${tmp_dir}/targets.json"
.mode json
SELECT * FROM targets WHERE project_id = $project_id ORDER BY created_at;
EOF

    sqlite3 "$DB_PATH" <<EOF > "${tmp_dir}/scans.json"
.mode json
SELECT * FROM scans WHERE project_id = $project_id ORDER BY started_at;
EOF

    sqlite3 "$DB_PATH" <<EOF > "${tmp_dir}/findings.json"
.mode json
SELECT * FROM findings WHERE project_id = $project_id ORDER BY
    CASE severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
        ELSE 5
    END, created_at DESC;
EOF

    sqlite3 "$DB_PATH" <<EOF > "${tmp_dir}/credentials.json"
.mode json
SELECT * FROM credentials WHERE project_id = $project_id ORDER BY created_at;
EOF

    # Combine into single JSON structure
    cat > "$output_file" <<JSONEOF
{
  "export_metadata": {
    "version": "2.1.0",
    "export_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "project_id": $project_id
  },
  "project": $(cat "${tmp_dir}/project.json" | head -1),
  "targets": $(cat "${tmp_dir}/targets.json"),
  "scans": $(cat "${tmp_dir}/scans.json"),
  "findings": $(cat "${tmp_dir}/findings.json"),
  "credentials": $(cat "${tmp_dir}/credentials.json")
}
JSONEOF

    # Cleanup
    rm -rf "$tmp_dir"

    log_success "Export saved to: $output_file"

    # File size
    if [ -f "$output_file" ]; then
        local size=$(wc -c < "$output_file")
        log_info "Export size: $(format_size $size)"
    fi
}

# Export findings only (for integration with other tools)
export_findings_json() {
    local project_id="$1"
    local output_file="${2:-findings.json}"
    local severity_filter="${3:-all}"

    if [ -z "$project_id" ]; then
        log_error "Project ID required"
        return 1
    fi

    log_info "Exporting findings to JSON..."

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
    f.status,
    f.created_at,
    t.hostname,
    t.ip,
    t.port,
    s.tool,
    s.command
FROM findings f
LEFT JOIN targets t ON t.id = f.target_id
LEFT JOIN scans s ON s.id = f.scan_id
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

    # Count findings by severity
    if command_exists jq; then
        local critical=$(jq '[.[] | select(.severity=="critical")] | length' "$output_file")
        local high=$(jq '[.[] | select(.severity=="high")] | length' "$output_file")
        local medium=$(jq '[.[] | select(.severity=="medium")] | length' "$output_file")

        echo
        log_info "Exported findings: $critical critical, $high high, $medium medium"
    fi
}

# Export statistics as JSON
export_stats_json() {
    local project_id="$1"
    local output_file="${2:-stats.json}"

    if [ -z "$project_id" ]; then
        log_error "Project ID required"
        return 1
    fi

    log_info "Exporting statistics to JSON..."

    # Get counts
    local total_targets=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM targets WHERE project_id = $project_id;")
    local total_scans=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM scans WHERE project_id = $project_id;")
    local total_findings=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM findings WHERE project_id = $project_id;")
    local total_credentials=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM credentials WHERE project_id = $project_id;")

    # Get findings by severity
    local critical=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM findings WHERE project_id = $project_id AND severity = 'critical';")
    local high=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM findings WHERE project_id = $project_id AND severity = 'high';")
    local medium=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM findings WHERE project_id = $project_id AND severity = 'medium';")
    local low=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM findings WHERE project_id = $project_id AND severity = 'low';")
    local info=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM findings WHERE project_id = $project_id AND severity = 'info';")

    # Get project info
    local project_name=$(sqlite3 "$DB_PATH" "SELECT name FROM projects WHERE id = $project_id;")

    # Create JSON
    cat > "$output_file" <<JSONEOF
{
  "project": {
    "id": $project_id,
    "name": "$project_name"
  },
  "statistics": {
    "targets": $total_targets,
    "scans": $total_scans,
    "findings": $total_findings,
    "credentials": $total_credentials
  },
  "findings_by_severity": {
    "critical": $critical,
    "high": $high,
    "medium": $medium,
    "low": $low,
    "info": $info
  },
  "risk_score": $(calculate_risk_score $critical $high $medium $low),
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSONEOF

    log_success "Statistics exported to: $output_file"
}

# Calculate risk score (0-100)
calculate_risk_score() {
    local critical="$1"
    local high="$2"
    local medium="$3"
    local low="$4"

    # Weight: critical=25, high=10, medium=3, low=1
    local score=$((critical * 25 + high * 10 + medium * 3 + low * 1))

    # Cap at 100
    [ "$score" -gt 100 ] && score=100

    echo "$score"
}

# Export for Burp Suite (XML format)
export_burp_xml() {
    local project_id="$1"
    local output_file="${2:-burp_import_${project_id}.xml}"

    if [ -z "$project_id" ]; then
        log_error "Project ID required"
        return 1
    fi

    log_info "Exporting to Burp Suite XML format..."

    cat > "$output_file" <<'XMLHEADER'
<?xml version="1.0"?>
<!DOCTYPE issues [
  <!ELEMENT issues (issue*)>
  <!ELEMENT issue (serialNumber, type, name, host, path, location, severity, confidence, issueBackground?, issueDetail?)>
]>
<issues burpVersion="2023.11">
XMLHEADER

    # Export findings as XML issues
    sqlite3 "$DB_PATH" <<EOF | while IFS='|' read -r id title severity description hostname ip; do
SELECT
    f.id,
    f.title,
    f.severity,
    f.description,
    COALESCE(t.hostname, 'unknown'),
    COALESCE(t.ip, '0.0.0.0')
FROM findings f
LEFT JOIN targets t ON t.id = f.target_id
WHERE f.project_id = $project_id
AND f.severity IN ('critical', 'high', 'medium');
EOF

        # Map severity
        local burp_severity="Information"
        case "$severity" in
            critical|high) burp_severity="High" ;;
            medium) burp_severity="Medium" ;;
            low) burp_severity="Low" ;;
        esac

        # Escape XML entities
        title=$(echo "$title" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        description=$(echo "$description" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        hostname=$(echo "$hostname" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

        cat >> "$output_file" <<XMLISSUE
  <issue>
    <serialNumber>$id</serialNumber>
    <type>0x$(printf '%08x' $id)</type>
    <name>$title</name>
    <host>$hostname</host>
    <path>/</path>
    <location>$hostname</location>
    <severity>$burp_severity</severity>
    <confidence>Certain</confidence>
    <issueBackground>LeKnight Autopilot Finding</issueBackground>
    <issueDetail>$description</issueDetail>
  </issue>
XMLISSUE
    done

    echo "</issues>" >> "$output_file"

    log_success "Burp Suite XML exported to: $output_file"
    log_info "Import in Burp: Target > Site map > Right-click > Import"
}

# Import findings from external JSON
import_findings_json() {
    local json_file="$1"
    local project_id="$2"

    if [ ! -f "$json_file" ]; then
        log_error "File not found: $json_file"
        return 1
    fi

    if [ -z "$project_id" ]; then
        log_error "Project ID required"
        return 1
    fi

    # Check if jq is installed
    if ! command_exists jq; then
        log_error "jq not installed (required for JSON import)"
        log_info "Install with: sudo apt-get install jq"
        return 1
    fi

    log_section "IMPORTING FINDINGS FROM JSON"

    local count=0
    jq -c '.[]' "$json_file" 2>/dev/null | while read -r finding; do
        local severity=$(echo "$finding" | jq -r '.severity // "info"')
        local type=$(echo "$finding" | jq -r '.type // "imported"')
        local title=$(echo "$finding" | jq -r '.title // "Imported Finding"')
        local description=$(echo "$finding" | jq -r '.description // ""')
        local evidence=$(echo "$finding" | jq -r '.evidence // ""')

        # Create finding (scan_id=0 for imported findings)
        db_finding_add "0" "$project_id" "0" "$severity" "$type" "$title" "$description" "$evidence"
        ((count++))

        log_debug "Imported: $title ($severity)"
    done

    log_success "Imported $count findings from $json_file"
}
