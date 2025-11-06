#!/bin/bash

# autopilot.sh - Autonomous scanning workflow
# Intelligently scans targets without human intervention
# Analyzes results and makes decisions about next steps

# Parse scope and create initial targets
parse_scope_to_targets() {
    local project_id="$1"
    local scope="$2"

    log_info "Parsing project scope and creating targets..."

    # Parse each line of scope
    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue

        # Trim whitespace
        line=$(echo "$line" | xargs)

        # Check if target already exists
        local existing=$(sqlite3 "$DB_PATH" <<EOF
SELECT id FROM targets
WHERE project_id = $project_id
AND (hostname = '$line' OR ip = '$line')
LIMIT 1;
EOF
)

        if [ -z "$existing" ]; then
            log_info "Adding target from scope: $line"
            project_add_target "$project_id" "$line"
        else
            log_debug "Target already exists: $line"
        fi
    done <<< "$scope"
}

# Main autopilot function - fully autonomous mode
autopilot_start() {
    local project_id=$(get_current_project)

    if [ -z "$project_id" ]; then
        log_error "No project loaded. Create or load a project first"
        return 1
    fi

    log_section "AUTOPILOT MODE ACTIVATED"
    log_info "Autonomous reconnaissance and exploitation framework"
    log_warning "This will run continuously until all targets are scanned"
    echo

    # Get project scope
    local scope=$(sqlite3 "$DB_PATH" "SELECT scope FROM projects WHERE id = $project_id;")

    if [ -z "$scope" ]; then
        log_error "No scope defined for project. Add targets first"
        return 1
    fi

    # Confirm start
    echo -e "${BRIGHT_BLUE}Scope:${RESET}"
    echo "$scope"
    echo

    if ! confirm "Start autonomous scanning?" "y"; then
        log_info "Autopilot cancelled"
        return 0
    fi

    # Parse scope and create initial targets if none exist
    local existing_targets=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM targets WHERE project_id = $project_id;")
    if [ "$existing_targets" -eq 0 ]; then
        log_info "No targets found in database, creating from scope..."
        parse_scope_to_targets "$project_id" "$scope"
        echo
    fi

    # Start autopilot loop
    local autopilot_start_time=$(date +%s)
    local iteration=0
    local new_targets_found=true

    while [ "$new_targets_found" = true ]; do
        ((iteration++))

        log_section "AUTOPILOT ITERATION $iteration"

        # Get all unscanned targets
        log_debug "Checking for unscanned targets in project $project_id..."
        local targets=$(get_unscanned_targets "$project_id")

        log_debug "Found targets: $(echo "$targets" | wc -l) line(s)"

        if [ -z "$targets" ]; then
            log_info "No more targets to scan"
            log_debug "Breaking autopilot loop - all targets processed"
            new_targets_found=false
            break
        fi

        local target_count=$(echo "$targets" | wc -l)
        log_info "Found $target_count targets to scan"

        # Scan each target
        local processed=0
        while IFS='|' read -r target_id hostname ip port; do
            ((processed++))

            # Determine target identifier
            local target=""
            [ -n "$hostname" ] && target="$hostname"
            [ -z "$target" ] && [ -n "$ip" ] && target="$ip"

            if [ -z "$target" ]; then
                log_warning "Skipping target $target_id (no hostname or IP)"
                continue
            fi

            log_info "[$processed/$target_count] Processing: $target"

            # Analyze and scan target
            autopilot_scan_target "$project_id" "$target_id" "$target"

            # Mark target as scanned
            mark_target_scanned "$target_id"

            # Small delay to be polite
            sleep 2
        done < <(echo "$targets")

        # Check if new targets were discovered
        local new_target_count=$(count_unscanned_targets "$project_id")
        log_debug "Unscanned targets remaining: $new_target_count"

        if [ "$new_target_count" -eq 0 ]; then
            log_debug "No new targets found, ending autopilot"
            new_targets_found=false
        else
            log_info "Discovered $new_target_count new targets, starting new iteration"
            log_debug "Waiting 5 seconds before next iteration..."
            sleep 5
        fi
    done

    # Autopilot complete
    local autopilot_end_time=$(date +%s)
    local total_duration=$((autopilot_end_time - autopilot_start_time))

    log_section "AUTOPILOT COMPLETED"
    echo -e "${BRIGHT_BLUE}Iterations:${RESET} $iteration"
    echo -e "${BRIGHT_BLUE}Total Duration:${RESET} ${total_duration}s"
    echo

    # Generate final report
    autopilot_summary "$project_id"

    log_success "Autopilot mission complete"
}

# Scan a single target intelligently
autopilot_scan_target() {
    local project_id="$1"
    local target_id="$2"
    local target="$3"

    log_info "Analyzing target type: $target"
    log_debug "Target ID: $target_id, Project ID: $project_id"

    # Determine target type and appropriate workflow
    if is_valid_ip "$target"; then
        log_debug "Target identified as IP address"
        autopilot_scan_ip "$project_id" "$target_id" "$target"

    elif is_valid_domain "$target"; then
        log_debug "Target identified as domain"
        autopilot_scan_domain "$project_id" "$target_id" "$target"

    elif is_valid_url "$target"; then
        log_debug "Target identified as URL"
        autopilot_scan_url "$project_id" "$target_id" "$target"

    else
        log_warning "Unknown target type, attempting generic scan"
        log_debug "Running fallback nmap scan on $target"
        run_tool "nmap" "$target"
    fi

    log_debug "Completed scan for target: $target"
}

# Scan IP address
autopilot_scan_ip() {
    local project_id="$1"
    local target_id="$2"
    local ip="$3"

    log_info "Target identified as IP address"

    # Step 1: Quick port scan
    log_info "Running quick port scan..."
    run_tool "nmap" "$ip" "-F"

    # Step 2: Analyze open ports and make decisions
    local open_ports=$(sqlite3 "$DB_PATH" <<EOF
SELECT DISTINCT port FROM findings
WHERE target_id = $target_id
AND type = 'open-port'
AND project_id = $project_id;
EOF
)

    if [ -z "$open_ports" ]; then
        log_info "No open ports found, skipping further enumeration"
        return 0
    fi

    log_info "Open ports detected, running targeted scans"

    # Check for web services
    if echo "$open_ports" | grep -qE "^(80|443|8080|8443)$"; then
        log_info "Web services detected"

        # Determine protocol
        local protocol="http"
        echo "$open_ports" | grep -qE "^(443|8443)$" && protocol="https"

        # Get actual port
        local web_port=$(echo "$open_ports" | grep -E "^(80|443|8080|8443)$" | head -1)

        local web_url="${protocol}://${ip}:${web_port}"

        # Run web reconnaissance
        workflow_web_quick "$web_url"
    fi

    # Check for SMB
    if echo "$open_ports" | grep -qE "^(139|445)$"; then
        log_info "SMB services detected"
        run_tool "enum4linux" "$ip" "-a" 2>/dev/null || log_debug "enum4linux not available"
    fi

    # Check for SSH
    if echo "$open_ports" | grep -qE "^22$"; then
        log_info "SSH service detected"
        run_tool "nmap" "$ip" "-p22 --script ssh-*"
    fi

    # Check for FTP
    if echo "$open_ports" | grep -qE "^21$"; then
        log_info "FTP service detected"
        run_tool "nmap" "$ip" "-p21 --script ftp-*"
    fi

    # Check for databases
    if echo "$open_ports" | grep -qE "^(1433|3306|5432|27017)$"; then
        log_info "Database services detected"
        run_tool "nmap" "$ip" "-sV -p1433,3306,5432,27017"
    fi

    log_success "IP scan completed"
}

# Scan domain
autopilot_scan_domain() {
    local project_id="$1"
    local target_id="$2"
    local domain="$3"

    log_info "Target identified as domain name"

    # Step 1: Subdomain enumeration
    log_info "Enumerating subdomains..."
    run_tool "subfinder" "$domain" "-silent"

    # Give parsers time to add subdomains to database
    sleep 2

    # Step 2: Web reconnaissance on main domain
    log_info "Scanning main domain..."
    workflow_web_quick "https://${domain}"

    # Step 3: DNS enumeration
    log_info "DNS enumeration..."
    run_tool "dnsenum" "$domain" 2>/dev/null || log_debug "dnsenum not available"

    # Step 4: Scan discovered subdomains (limited to prevent infinite loop)
    local subdomain_count=$(sqlite3 "$DB_PATH" <<EOF
SELECT COUNT(*) FROM targets
WHERE project_id = $project_id
AND tags LIKE '%subdomain%'
AND hostname LIKE '%$domain';
EOF
)

    if [ "$subdomain_count" -gt 0 ]; then
        log_info "Found $subdomain_count subdomains, scanning first 10..."

        local subdomains=$(sqlite3 "$DB_PATH" <<EOF
SELECT hostname FROM targets
WHERE project_id = $project_id
AND tags LIKE '%subdomain%'
AND hostname LIKE '%$domain'
LIMIT 10;
EOF
)

        echo "$subdomains" | while read -r subdomain; do
            log_info "Quick scan: $subdomain"
            workflow_web_quick "https://${subdomain}"
            sleep 2
        done
    fi

    log_success "Domain scan completed"
}

# Scan URL
autopilot_scan_url() {
    local project_id="$1"
    local target_id="$2"
    local url="$3"

    log_info "Target identified as URL"

    # Run web reconnaissance workflow
    workflow_web_medium "$url"

    log_success "URL scan completed"
}

# Get unscanned targets
get_unscanned_targets() {
    local project_id="$1"

    # Get targets that haven't been scanned yet by autopilot
    sqlite3 "$DB_PATH" <<EOF
SELECT t.id, t.hostname, t.ip, t.port
FROM targets t
WHERE t.project_id = $project_id
AND (t.autopilot_status IS NULL OR t.autopilot_status = 'pending')
ORDER BY t.created_at ASC;
EOF
}

# Count unscanned targets
count_unscanned_targets() {
    local project_id="$1"

    sqlite3 "$DB_PATH" <<EOF
SELECT COUNT(*)
FROM targets t
WHERE t.project_id = $project_id
AND (t.autopilot_status IS NULL OR t.autopilot_status = 'pending');
EOF
}

# Mark target as scanned (add a marker scan)
mark_target_scanned() {
    local target_id="$1"

    sqlite3 "$DB_PATH" <<EOF
UPDATE targets
SET autopilot_status = 'completed',
    autopilot_completed_at = CURRENT_TIMESTAMP
WHERE id = $target_id;
EOF

    log_debug "Target $target_id marked as scanned by autopilot"
}

# Autopilot summary report
autopilot_summary() {
    local project_id="$1"

    log_section "AUTOPILOT SUMMARY"

    # Get statistics
    local total_targets=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM targets WHERE project_id = $project_id;")
    local total_scans=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM scans WHERE project_id = $project_id;")
    local total_findings=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM findings WHERE project_id = $project_id;")
    local total_credentials=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM credentials WHERE project_id = $project_id;")

    echo -e "${BRIGHT_BLUE}Targets Discovered:${RESET} $total_targets"
    echo -e "${BRIGHT_BLUE}Scans Executed:${RESET} $total_scans"
    echo -e "${BRIGHT_BLUE}Findings:${RESET} $total_findings"
    echo -e "${BRIGHT_BLUE}Credentials:${RESET} $total_credentials"
    echo

    # Findings by severity
    echo -e "${BRIGHT_BLUE}Findings by Severity:${RESET}"
    db_finding_stats "$project_id"
    echo

    # Top findings
    echo -e "${BRIGHT_BLUE}Top Critical/High Findings:${RESET}"
    sqlite3 -column "$DB_PATH" <<EOF
SELECT severity, title, created_at
FROM findings
WHERE project_id = $project_id
AND severity IN ('critical', 'high')
ORDER BY
    CASE severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
    END,
    created_at DESC
LIMIT 10;
EOF
    echo

    # Discovered credentials
    if [ "$total_credentials" -gt 0 ]; then
        echo -e "${BRIGHT_BLUE}Discovered Credentials:${RESET}"
        sqlite3 -column "$DB_PATH" <<EOF
SELECT username, service, source
FROM credentials
WHERE project_id = $project_id
LIMIT 10;
EOF
        echo
    fi

    log_info "Full report available with: leknight report generate"
}

# Continuous monitoring mode
autopilot_monitor() {
    local project_id=$(get_current_project)

    if [ -z "$project_id" ]; then
        log_error "No project loaded"
        return 1
    fi

    local interval="${1:-3600}"  # Default: 1 hour

    log_section "AUTOPILOT MONITORING MODE"
    log_info "Scanning interval: ${interval}s"
    log_warning "Press Ctrl+C to stop"
    echo

    while true; do
        log_info "Starting monitoring scan at $(date)"

        # Run autopilot
        autopilot_start

        # Wait for next interval
        log_info "Next scan in ${interval}s"
        sleep "$interval"
    done
}

# Smart rescan - rescan targets with high-severity findings
autopilot_rescan_high_value() {
    local project_id=$(get_current_project)

    if [ -z "$project_id" ]; then
        log_error "No project loaded"
        return 1
    fi

    log_section "RESCANNING HIGH-VALUE TARGETS"

    # Get targets with critical/high findings
    local high_value_targets=$(sqlite3 "$DB_PATH" <<EOF
SELECT DISTINCT t.id, t.hostname, t.ip
FROM targets t
JOIN findings f ON f.target_id = t.id
WHERE t.project_id = $project_id
AND f.severity IN ('critical', 'high')
ORDER BY f.severity;
EOF
)

    if [ -z "$high_value_targets" ]; then
        log_info "No high-value targets found"
        return 0
    fi

    echo "$high_value_targets" | while IFS='|' read -r target_id hostname ip; do
        local target=""
        [ -n "$hostname" ] && target="$hostname"
        [ -z "$target" ] && [ -n "$ip" ] && target="$ip"

        log_info "Rescanning high-value target: $target"
        autopilot_scan_target "$project_id" "$target_id" "$target"

        sleep 5
    done

    log_success "High-value targets rescanned"
}

# Exploit mode - attempt to exploit discovered vulnerabilities
autopilot_exploit_mode() {
    local project_id=$(get_current_project)

    if [ -z "$project_id" ]; then
        log_error "No project loaded"
        return 1
    fi

    log_section "AUTOPILOT EXPLOIT MODE"
    log_warning "This will attempt to exploit discovered vulnerabilities"
    log_warning "Ensure you have authorization before proceeding!"
    echo

    if ! confirm "Proceed with exploitation attempts?" "n"; then
        log_info "Exploit mode cancelled"
        return 0
    fi

    # Get exploitable findings
    local exploitable=$(sqlite3 "$DB_PATH" <<EOF
SELECT f.id, f.type, f.title, t.hostname, t.ip
FROM findings f
JOIN targets t ON t.id = f.target_id
WHERE f.project_id = $project_id
AND f.severity IN ('critical', 'high')
AND f.type IN ('sql-injection', 'rce', 'command-injection', 'file-upload')
ORDER BY f.severity;
EOF
)

    if [ -z "$exploitable" ]; then
        log_info "No exploitable findings found"
        return 0
    fi

    echo "$exploitable" | while IFS='|' read -r finding_id vuln_type title hostname ip; do
        log_info "Attempting exploitation: $title"

        local target=""
        [ -n "$hostname" ] && target="$hostname"
        [ -z "$target" ] && [ -n "$ip" ] && target="$ip"

        # Attempt exploitation based on vulnerability type
        case "$vuln_type" in
            sql-injection)
                log_info "Running SQLMap with aggressive options"
                run_tool "sqlmap" "$target" "--batch --level=5 --risk=3"
                ;;
            *)
                log_info "No automated exploit available for $vuln_type"
                ;;
        esac

        sleep 5
    done

    log_success "Exploitation attempts completed"
}
