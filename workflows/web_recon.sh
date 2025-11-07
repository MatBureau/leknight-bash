#!/bin/bash

# web_recon.sh - Complete web reconnaissance workflow
# Automated workflow for web application reconnaissance

workflow_web_recon() {
    local target="$1"
    local depth="${2:-medium}"  # quick, medium, deep

    # Validate target
    if [ -z "$target" ]; then
        log_error "Target required"
        return 1
    fi

    # Ensure project is loaded
    local project_id=$(get_current_project)
    if [ -z "$project_id" ]; then
        log_error "No project loaded"
        return 1
    fi

    # Start workflow
    local start_time=$(date +%s)

    # Define workflow steps based on depth
    local total_steps=0
    case "$depth" in
        quick)
            total_steps=3
            ;;
        medium)
            total_steps=6
            ;;
        deep)
            total_steps=10
            ;;
    esac

    # Create workflow run
    local workflow_id=$(db_workflow_create "$project_id" "web_recon" "$target" "$total_steps")

    log_workflow_start "Web Reconnaissance" "$target"
    log_info "Depth: $depth ($total_steps steps)"

    local current_step=0

    # STEP 1: Technology Detection
    ((current_step++))
    log_workflow_step "$current_step" "$total_steps" "Technology Detection (WhatWeb)"
    db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "Technology Detection"

    # Test WhatWeb first before using it
    if command_exists "whatweb"; then
        if whatweb --version &>/dev/null; then
            run_tool "whatweb" "$target" "-v" || log_warning "WhatWeb failed"
        else
            log_warning "WhatWeb is installed but broken. Skipping. Fix with: sudo apt-get install --reinstall whatweb"
        fi
    else
        log_warning "WhatWeb not installed. Skipping."
    fi

    # STEP 2: Web Server Vulnerability Scan
    ((current_step++))
    log_workflow_step "$current_step" "$total_steps" "Web Vulnerability Scan (Nikto)"
    db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "Web Vulnerability Scan"

    if check_and_install_tool "nikto" "sudo apt-get install -y nikto" true; then
        run_tool "nikto" "$target" || log_warning "Nikto failed"
    fi

    # STEP 3: Quick SSL/TLS Check
    ((current_step++))
    log_workflow_step "$current_step" "$total_steps" "SSL/TLS Analysis"
    db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "SSL/TLS Analysis"

    if echo "$target" | grep -q "https"; then
        local hostname=$(extract_hostname "$target")
        if check_and_install_tool "sslscan" "sudo apt-get install -y sslscan" true; then
            run_tool "sslscan" "$hostname" || log_warning "SSLScan failed"
        fi
    fi

    # Medium and Deep only steps
    if [[ "$depth" == "medium" || "$depth" == "deep" ]]; then

        # STEP 4: Directory Bruteforce
        ((current_step++))
        log_workflow_step "$current_step" "$total_steps" "Directory Bruteforce"
        db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "Directory Bruteforce"

        if check_and_install_tool "ffuf" "sudo apt-get install -y ffuf" true; then
            local wordlist="/usr/share/wordlists/dirb/common.txt"
            if [ -f "$wordlist" ]; then
                run_tool "ffuf" "$target" "-u ${target}/FUZZ -w $wordlist -mc 200,301,302,401,403" || log_warning "FFUF failed"
            else
                log_warning "Wordlist not found: $wordlist"
            fi
        fi

        # STEP 5: Template-based Scanning (Nuclei)
        ((current_step++))
        log_workflow_step "$current_step" "$total_steps" "Template-based Scanning (Nuclei)"
        db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "Nuclei Scan"

        if command_exists "nuclei"; then
            run_tool "nuclei" "$target" "-severity critical,high,medium" || log_warning "Nuclei failed"
        else
            log_info "Nuclei not installed, skipping"
        fi

        # STEP 6: Subdomain Enumeration (if domain)
        if is_valid_domain "$(extract_hostname "$target")"; then
            ((current_step++))
            log_workflow_step "$current_step" "$total_steps" "Subdomain Enumeration"
            db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "Subdomain Enumeration"

            local domain=$(extract_hostname "$target")

            if check_and_install_tool "subfinder" "go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest" true; then
                run_tool "subfinder" "$domain" "-silent" || log_warning "Subfinder failed"
            fi
        fi
    fi

    # Deep only steps
    if [ "$depth" == "deep" ]; then

        # STEP 7: JavaScript Analysis
        ((current_step++))
        log_workflow_step "$current_step" "$total_steps" "JavaScript Analysis"
        db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "JavaScript Analysis"

        if command_exists "hakrawler"; then
            run_tool "hakrawler" "$target" "-depth 2" || log_warning "Hakrawler failed"
        fi

        # STEP 8: Parameter Discovery
        ((current_step++))
        log_workflow_step "$current_step" "$total_steps" "Parameter Discovery"
        db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "Parameter Discovery"

        if command_exists "arjun"; then
            run_tool "arjun" "$target" || log_warning "Arjun failed"
        fi

        # STEP 9: Screenshot
        ((current_step++))
        log_workflow_step "$current_step" "$total_steps" "Taking Screenshot"
        db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "Screenshot"

        if check_and_install_tool "gowitness" "go install github.com/sensepost/gowitness@latest" true; then
            local screenshot_dir="${LEKNIGHT_ROOT}/data/projects/${project_id}/screenshots"
            mkdir -p "$screenshot_dir"
            run_tool "gowitness" "$target" "single -u $target --screenshot-path $screenshot_dir" || log_warning "Gowitness failed"
        fi

        # STEP 10: WordPress Detection (if applicable)
        ((current_step++))
        log_workflow_step "$current_step" "$total_steps" "WordPress Detection"
        db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "WordPress Detection"

        # Quick check if it's WordPress
        local is_wordpress=$(curl -s -L "$target" | grep -c "wp-content")
        if [ "$is_wordpress" -gt 0 ]; then
            log_info "WordPress detected, running WPScan"
            if check_and_install_tool "wpscan" "sudo gem install wpscan" true; then
                run_tool "wpscan" "$target" "--enumerate vp,vt,u" || log_warning "WPScan failed"
            fi
        else
            log_info "Not a WordPress site, skipping WPScan"
        fi
    fi

    # Workflow complete
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    db_workflow_complete "$workflow_id" "completed"
    log_workflow_complete "Web Reconnaissance" "$duration"

    # Show summary
    echo
    log_section "WORKFLOW SUMMARY"
    echo -e "${BRIGHT_BLUE}Target:${RESET} $target"
    echo -e "${BRIGHT_BLUE}Depth:${RESET} $depth"
    echo -e "${BRIGHT_BLUE}Duration:${RESET} ${duration}s"
    echo

    # Show findings summary
    local findings=$(db_finding_stats "$project_id")
    echo -e "${BRIGHT_BLUE}New Findings:${RESET}"
    echo "$findings"
    echo

    log_success "Web reconnaissance workflow completed"
}

# Quick web recon (essential tools only)
workflow_web_quick() {
    workflow_web_recon "$1" "quick"
}

# Medium web recon (recommended)
workflow_web_medium() {
    workflow_web_recon "$1" "medium"
}

# Deep web recon (comprehensive)
workflow_web_deep() {
    workflow_web_recon "$1" "deep"
}

# Interactive workflow launcher
workflow_web_interactive() {
    echo
    log_section "WEB RECONNAISSANCE WORKFLOW"

    read -rp "${BRIGHT_BLUE}Target URL:${RESET} " target

    if [ -z "$target" ]; then
        log_error "Target required"
        return 1
    fi

    # Add protocol if missing
    if ! echo "$target" | grep -qE "^https?://"; then
        target="https://${target}"
    fi

    echo
    echo "Select depth:"
    echo "  ${RED}[1]${RESET} ${BRIGHT_BLUE}Quick${RESET} - Basic reconnaissance (3 steps, ~5 min)"
    echo "  ${RED}[2]${RESET} ${BRIGHT_BLUE}Medium${RESET} - Standard reconnaissance (6 steps, ~15 min)"
    echo "  ${RED}[3]${RESET} ${BRIGHT_BLUE}Deep${RESET} - Comprehensive reconnaissance (10 steps, ~30 min)"
    echo

    read -rp "${BRIGHT_BLUE}Choice${RESET}${BRIGHT_RED} \$${RESET} " depth_choice

    case "$depth_choice" in
        1)
            workflow_web_recon "$target" "quick"
            ;;
        2)
            workflow_web_recon "$target" "medium"
            ;;
        3)
            workflow_web_recon "$target" "deep"
            ;;
        *)
            log_error "Invalid choice"
            return 1
            ;;
    esac
}

# Scan discovered subdomains
workflow_scan_subdomains() {
    local project_id=$(get_current_project)

    if [ -z "$project_id" ]; then
        log_error "No project loaded"
        return 1
    fi

    # Get all subdomain targets
    local subdomains=$(sqlite3 "$DB_PATH" <<EOF
SELECT hostname FROM targets
WHERE project_id = $project_id
AND tags LIKE '%subdomain%'
AND hostname IS NOT NULL;
EOF
)

    if [ -z "$subdomains" ]; then
        log_info "No subdomains found to scan"
        return 0
    fi

    local subdomain_count=$(echo "$subdomains" | wc -l)

    log_section "SCANNING DISCOVERED SUBDOMAINS"
    log_info "Found $subdomain_count subdomains to scan"

    if ! confirm "Proceed with scanning all subdomains?" "y"; then
        return 0
    fi

    local count=0
    echo "$subdomains" | while read -r subdomain; do
        ((count++))
        log_info "[$count/$subdomain_count] Scanning: $subdomain"

        # Quick scan on each subdomain
        workflow_web_quick "https://${subdomain}"

        # Small delay to avoid rate limiting
        sleep 2
    done

    log_success "Subdomain scanning completed"
}
