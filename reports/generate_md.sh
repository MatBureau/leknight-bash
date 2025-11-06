#!/bin/bash

# generate_md.sh - Generate Markdown reports
# Creates comprehensive Markdown reports for projects

generate_markdown_report() {
    local project_id="${1:-$(get_current_project)}"
    local output_file="$2"

    if [ -z "$project_id" ]; then
        log_error "No project specified"
        return 1
    fi

    # Get project info
    local project_name=$(sqlite3 "$DB_PATH" "SELECT name FROM projects WHERE id = $project_id;")
    local project_desc=$(sqlite3 "$DB_PATH" "SELECT description FROM projects WHERE id = $project_id;")
    local created_at=$(sqlite3 "$DB_PATH" "SELECT created_at FROM projects WHERE id = $project_id;")

    # Generate output filename if not provided
    if [ -z "$output_file" ]; then
        local timestamp=$(date '+%Y%m%d_%H%M%S')
        local sanitized_name=$(sanitize_filename "$project_name")
        output_file="${LEKNIGHT_ROOT}/data/projects/${project_id}/reports/${sanitized_name}_${timestamp}.md"
    fi

    mkdir -p "$(dirname "$output_file")"

    log_info "Generating Markdown report..."

    # Generate report
    cat > "$output_file" <<EOF
# Security Assessment Report

**Project:** $project_name
**Generated:** $(date '+%Y-%m-%d %H:%M:%S')
**Created:** $created_at

---

## Executive Summary

$project_desc

### Quick Statistics

EOF

    # Add statistics
    local total_targets=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM targets WHERE project_id = $project_id;")
    local total_scans=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM scans WHERE project_id = $project_id;")
    local total_findings=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM findings WHERE project_id = $project_id;")
    local total_creds=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM credentials WHERE project_id = $project_id;")

    cat >> "$output_file" <<EOF
- **Targets Tested:** $total_targets
- **Scans Performed:** $total_scans
- **Findings Identified:** $total_findings
- **Credentials Discovered:** $total_creds

---

## Findings by Severity

EOF

    # Get findings stats
    local findings_stats=$(db_finding_stats "$project_id")
    local critical=$(echo "$findings_stats" | awk '{print $1}')
    local high=$(echo "$findings_stats" | awk '{print $2}')
    local medium=$(echo "$findings_stats" | awk '{print $3}')
    local low=$(echo "$findings_stats" | awk '{print $4}')
    local info=$(echo "$findings_stats" | awk '{print $5}')

    cat >> "$output_file" <<EOF
| Severity | Count |
|----------|-------|
| 🔴 Critical | $critical |
| 🟠 High | $high |
| 🟡 Medium | $medium |
| 🔵 Low | $low |
| ⚪ Info | $info |

---

## Critical Findings

EOF

    # Add critical findings
    sqlite3 "$DB_PATH" <<EOF_SQL | while IFS='|' read -r title description target_host created; do
SELECT title, description,
       COALESCE((SELECT hostname FROM targets WHERE id = findings.target_id),
                (SELECT ip FROM targets WHERE id = findings.target_id)),
       created_at
FROM findings
WHERE project_id = $project_id
AND severity = 'critical'
ORDER BY created_at DESC;
EOF_SQL
        cat >> "$output_file" <<EOF

### $title

**Target:** $target_host
**Discovered:** $created

**Description:**
$description

---
EOF
    done

    # Add high findings
    cat >> "$output_file" <<EOF

## High Severity Findings

EOF

    sqlite3 "$DB_PATH" <<EOF_SQL | while IFS='|' read -r title description target_host created; do
SELECT title, description,
       COALESCE((SELECT hostname FROM targets WHERE id = findings.target_id),
                (SELECT ip FROM targets WHERE id = findings.target_id)),
       created_at
FROM findings
WHERE project_id = $project_id
AND severity = 'high'
ORDER BY created_at DESC;
EOF_SQL
        cat >> "$output_file" <<EOF

### $title

**Target:** $target_host
**Discovered:** $created

**Description:**
$description

---
EOF
    done

    # Add targets section
    cat >> "$output_file" <<EOF

## Tested Targets

| Target | IP | Open Ports | Findings |
|--------|-----|------------|----------|
EOF

    sqlite3 "$DB_PATH" <<EOF_SQL | while IFS='|' read -r hostname ip port finding_count; do
SELECT COALESCE(hostname, '-'), COALESCE(ip, '-'), COALESCE(port, '-'),
       (SELECT COUNT(*) FROM findings WHERE target_id = targets.id)
FROM targets
WHERE project_id = $project_id
ORDER BY hostname, ip;
EOF_SQL
        cat >> "$output_file" <<EOF
| $hostname | $ip | $port | $finding_count |
EOF
    done

    # Add credentials section if any
    if [ "$total_creds" -gt 0 ]; then
        cat >> "$output_file" <<EOF

---

## Discovered Credentials

| Username | Service | Source | Target |
|----------|---------|--------|--------|
EOF

        sqlite3 "$DB_PATH" <<EOF_SQL | while IFS='|' read -r username service source target_host; do
SELECT username, COALESCE(service, '-'), COALESCE(source, '-'),
       COALESCE((SELECT hostname FROM targets WHERE id = credentials.target_id),
                (SELECT ip FROM targets WHERE id = credentials.target_id), '-')
FROM credentials
WHERE project_id = $project_id
ORDER BY created_at DESC;
EOF_SQL
            # Mask password for security
            cat >> "$output_file" <<EOF
| $username | $service | $source | $target_host |
EOF
        done
    fi

    # Add scan history
    cat >> "$output_file" <<EOF

---

## Scan History

| Tool | Target | Status | Executed |
|------|--------|--------|----------|
EOF

    sqlite3 "$DB_PATH" <<EOF_SQL | while IFS='|' read -r tool target_host status started; do
SELECT tool,
       COALESCE((SELECT hostname FROM targets WHERE id = scans.target_id),
                (SELECT ip FROM targets WHERE id = scans.target_id), '-'),
       status,
       started_at
FROM scans
WHERE project_id = $project_id
ORDER BY started_at DESC
LIMIT 50;
EOF_SQL
        cat >> "$output_file" <<EOF
| $tool | $target_host | $status | $started |
EOF
    done

    # Add footer
    cat >> "$output_file" <<EOF

---

## Methodology

This assessment was conducted using LeKnight, an automated security testing framework.
The following tools and techniques were employed:

- Network reconnaissance (Nmap, Masscan)
- Web application testing (Nikto, Nuclei, WhatWeb)
- Subdomain enumeration (Subfinder, Amass)
- Vulnerability scanning
- Automated exploitation checks

---

**Report generated by LeKnight**
*https://github.com/MatBureau/leknight-bash*

EOF

    log_success "Markdown report generated: $output_file"
    echo "$output_file"
}

# Generate quick summary
generate_quick_summary() {
    local project_id="${1:-$(get_current_project)}"

    if [ -z "$project_id" ]; then
        log_error "No project loaded"
        return 1
    fi

    log_section "PROJECT SUMMARY"

    local project_name=$(sqlite3 "$DB_PATH" "SELECT name FROM projects WHERE id = $project_id;")
    echo -e "${BRIGHT_BLUE}Project:${RESET} $project_name"
    echo

    db_project_stats "$project_id"
}

# Export to CSV
export_findings_csv() {
    local project_id="${1:-$(get_current_project)}"
    local output_file="$2"

    if [ -z "$project_id" ]; then
        log_error "No project specified"
        return 1
    fi

    if [ -z "$output_file" ]; then
        local timestamp=$(date '+%Y%m%d_%H%M%S')
        output_file="${LEKNIGHT_ROOT}/data/exports/findings_${timestamp}.csv"
    fi

    mkdir -p "$(dirname "$output_file")"

    sqlite3 -csv "$DB_PATH" <<EOF > "$output_file"
.headers on
SELECT
    f.severity,
    f.type,
    f.title,
    f.description,
    COALESCE(t.hostname, t.ip) as target,
    f.created_at
FROM findings f
LEFT JOIN targets t ON t.id = f.target_id
WHERE f.project_id = $project_id
ORDER BY
    CASE f.severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
        ELSE 5
    END,
    f.created_at DESC;
EOF

    log_success "Findings exported to CSV: $output_file"
    echo "$output_file"
}
