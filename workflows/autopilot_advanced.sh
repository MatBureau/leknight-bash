#!/bin/bash

# Advanced Autopilot - 5-Phase Security Testing Pipeline
# Integrates all advanced vulnerability testing modules

# Source required modules
source "$(dirname "${BASH_SOURCE[0]}")/fuzzing_pipeline.sh"
source "$(dirname "${BASH_SOURCE[0]}")/dns_dump_advanced.sh"
source "$(dirname "${BASH_SOURCE[0]}")/vulnerability_testing.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/result_formatter.sh"

# Override autopilot_scan_target with advanced 5-phase pipeline
autopilot_scan_target_advanced() {
    local project_id="$1"
    local target_id="$2"
    local target="$3"

    log_section "ADVANCED SECURITY TESTING PIPELINE"
    log_info "Target: $target"
    echo ""

    # Determine target type
    if is_valid_ip "$target"; then
        autopilot_scan_ip_advanced "$project_id" "$target_id" "$target"
    elif is_valid_domain "$target"; then
        autopilot_scan_domain_advanced "$project_id" "$target_id" "$target"
    elif is_valid_url "$target"; then
        autopilot_scan_url_advanced "$project_id" "$target_id" "$target"
    else
        log_warning "Unknown target type, using standard scan"
        autopilot_scan_target "$project_id" "$target_id" "$target"
    fi
}

# Advanced domain scanning with 5 phases
autopilot_scan_domain_advanced() {
    local project_id="$1"
    local target_id="$2"
    local domain="$3"

    # Get protocol from database (respects user's explicit protocol choice)
    log_debug "Loading protocol for target ID $target_id..."
    local protocol=$(sqlite3 "$DB_PATH" "SELECT protocol FROM targets WHERE id = $target_id LIMIT 1;" 2>/dev/null)

    # Fallback to http if protocol not found
    if [ -z "$protocol" ]; then
        protocol="http"
        log_debug "Protocol not found in database, defaulting to http"
    else
        log_debug "Using protocol from database: $protocol"
    fi

    local target_url="${protocol}://${domain}"
    log_info "Testing target: $target_url"

    # ========================================
    # PHASE 1: RECONNAISSANCE
    # ========================================
    log_phase "1/5" "Reconnaissance"

    # DNS enumeration
    dns_dump_advanced "$domain" "$project_id"

    # Subdomain enumeration
    log_info "[Phase 1] Subdomain enumeration"
    run_tool "subfinder" "$domain" "-d $domain"
    run_tool "amass" "$domain" "enum -passive -d $domain"

    # Technology detection
    log_info "[Phase 1] Technology fingerprinting"
    run_tool "whatweb" "$target_url" ""

    # ========================================
    # PHASE 2: ENUMERATION
    # ========================================
    log_phase "2/5" "Enumeration"

    # Port scanning
    log_info "[Phase 2] Port scanning"
    run_tool "nmap" "$domain" "-sV -sC"

    # Directory and file fuzzing
    log_info "[Phase 2] Fuzzing for endpoints"
    fuzzing_pipeline "$target_url" "$project_id" "medium"

    # SSL/TLS analysis
    log_info "[Phase 2] SSL/TLS testing"
    run_tool "sslyze" "$domain" ""

    # ========================================
    # PHASE 3: VULNERABILITY SCANNING
    # ========================================
    log_phase "3/5" "Vulnerability Scanning"

    # Nuclei templates
    log_info "[Phase 3] Running Nuclei vulnerability scans"
    run_tool "nuclei" "$target_url" "-severity critical,high,medium"

    # Nikto web scanner
    log_info "[Phase 3] Nikto web vulnerability scanner"
    run_tool "nikto" "$target_url" ""

    # WPScan if WordPress detected
    if detect_wordpress "$target_url"; then
        log_info "[Phase 3] WordPress detected - running WPScan"
        run_tool "wpscan" "$target_url" "--enumerate p,t,u"
    fi

    # ========================================
    # PHASE 4: EXPLOITATION TESTING
    # ========================================
    log_phase "4/5" "Vulnerability Exploitation Testing"

    log_info "[Phase 4] Testing OWASP Top 10 vulnerabilities"

    # Run comprehensive vulnerability testing
    vulnerability_testing_pipeline "$target_url" "$project_id" "all"

    # ========================================
    # PHASE 5: POST-EXPLOITATION & REPORTING
    # ========================================
    log_phase "5/5" "Post-Exploitation & Reporting"

    # Check if any critical/high vulnerabilities were found
    local critical_findings=$(db_execute "SELECT COUNT(*) FROM findings WHERE project_id=$project_id AND severity IN ('critical', 'high')" 2>/dev/null | tail -1)

    if [ "$critical_findings" -gt 0 ]; then
        log_critical "[Phase 5] Found $critical_findings critical/high severity findings!"

        # Format findings for exploitation
        log_info "[Phase 5] Formatting findings for exploitation"
        format_findings_for_exploitation "$project_id"

        # Optional: Run exploitation if enabled
        if [ "${AUTOPILOT_AUTO_EXPLOIT:-false}" = "true" ]; then
            log_warning "[Phase 5] Auto-exploitation is ENABLED"
            if confirm "Attempt automated exploitation?" "n"; then
                autopilot_exploit_mode "$project_id"
            fi
        fi
    else
        log_info "[Phase 5] No critical/high findings detected"
    fi

    # Generate comprehensive report
    log_info "[Phase 5] Generating final report"
    generate_markdown_report "$project_id"

    log_success "5-Phase security testing completed for $domain"
}

# Advanced URL scanning
autopilot_scan_url_advanced() {
    local project_id="$1"
    local target_id="$2"
    local url="$3"

    log_info "Advanced URL scanning: $url"

    # Extract domain from URL
    local domain=$(echo "$url" | grep -oP 'https?://\K[^/]+')

    # Phase 1: Light reconnaissance
    log_phase "1/5" "Reconnaissance"
    run_tool "whatweb" "$url" ""

    # Phase 2: Fuzzing
    log_phase "2/5" "Enumeration"
    fuzzing_pipeline "$url" "$project_id" "quick"

    # Phase 3: Vulnerability scanning
    log_phase "3/5" "Vulnerability Scanning"
    run_tool "nuclei" "$url" "-severity critical,high"

    # Phase 4: Exploitation testing
    log_phase "4/5" "Exploitation Testing"
    vulnerability_testing_pipeline "$url" "$project_id" "all"

    # Phase 5: Reporting
    log_phase "5/5" "Reporting"
    format_findings_for_exploitation "$project_id"

    log_success "Advanced URL scan completed"
}

# Advanced IP scanning
autopilot_scan_ip_advanced() {
    local project_id="$1"
    local target_id="$2"
    local ip="$3"

    log_info "Advanced IP scanning: $ip"

    # Phase 1: Host discovery
    log_phase "1/5" "Reconnaissance"
    run_tool "nmap" "$ip" "-sn"

    # Phase 2: Port and service enumeration
    log_phase "2/5" "Enumeration"
    run_tool "nmap" "$ip" "-sV -sC -p-"

    # Phase 3: Vulnerability scanning
    log_phase "3/5" "Vulnerability Scanning"
    run_tool "nmap" "$ip" "--script vuln"

    # Phase 4: Service-specific testing
    log_phase "4/5" "Service-Specific Testing"

    # Detect and test web services
    local http_ports=$(db_execute "SELECT DISTINCT port FROM findings WHERE project_id=$project_id AND target_id=$target_id AND (service LIKE '%http%' OR port IN (80,443,8080,8443))" 2>/dev/null)

    if [ -n "$http_ports" ]; then
        while read -r port; do
            [ -z "$port" ] && continue

            local proto="http"
            [ "$port" = "443" ] || [ "$port" = "8443" ] && proto="https"

            local web_url="${proto}://${ip}:${port}"
            log_info "Testing web service: $web_url"

            # Run web vulnerability testing
            vulnerability_testing_pipeline "$web_url" "$project_id" "all"
        done <<< "$http_ports"
    fi

    # Phase 5: Reporting
    log_phase "5/5" "Reporting"
    format_findings_for_exploitation "$project_id"

    log_success "Advanced IP scan completed"
}

# Helper: Log phase header
log_phase() {
    local phase=$1
    local name=$2

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BRIGHT_BLUE}█ PHASE $phase: $name${RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Helper: Detect WordPress
detect_wordpress() {
    local url=$1

    local response=$(curl -s -L "$url" 2>/dev/null)

    if echo "$response" | grep -qiE "wp-content|wp-includes|wordpress"; then
        return 0
    fi

    return 1
}

# Autopilot exploit mode (automated exploitation)
autopilot_exploit_mode() {
    local project_id=$1

    log_section "AUTOPILOT EXPLOITATION MODE"
    log_critical "⚠️  DANGER: This will attempt to exploit discovered vulnerabilities!"
    echo ""

    if ! confirm "Are you ABSOLUTELY SURE you want to proceed with automated exploitation?" "n"; then
        log_info "Exploitation cancelled"
        return 0
    fi

    if ! confirm "Have you confirmed you have WRITTEN AUTHORIZATION to exploit these systems?" "n"; then
        log_critical "Exploitation aborted - authorization required"
        return 1
    fi

    log_warning "Starting automated exploitation..."

    # Get all critical RCE findings
    local rce_findings=$(db_execute "SELECT id FROM findings WHERE project_id=$project_id AND type LIKE 'rce%' AND severity='critical'" 2>/dev/null)

    if [ -n "$rce_findings" ]; then
        log_critical "Found RCE vulnerabilities - this is a placeholder"
        log_info "In a real scenario, this would:"
        log_info "  1. Generate reverse shell payloads"
        log_info "  2. Start listeners"
        log_info "  3. Execute exploitation scripts"
        log_info "  4. Establish persistence"
        log_info "  5. Perform privilege escalation"
        log_warning "Automated exploitation is dangerous and requires explicit authorization"
    fi

    # SQLi exploitation
    local sqli_findings=$(db_execute "SELECT id FROM findings WHERE project_id=$project_id AND type LIKE 'sqli%'" 2>/dev/null)

    if [ -n "$sqli_findings" ]; then
        log_info "SQL injection findings detected"
        log_info "Exploitation scripts available in: data/projects/${project_id}/exploits/"
    fi

    log_success "Exploitation assessment complete"
}

# Export enhanced functions
export -f autopilot_scan_target_advanced
export -f autopilot_scan_domain_advanced
export -f autopilot_scan_url_advanced
export -f autopilot_scan_ip_advanced
export -f autopilot_exploit_mode
export -f log_phase
export -f detect_wordpress
