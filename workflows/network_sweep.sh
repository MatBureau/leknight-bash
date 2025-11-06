#!/bin/bash

# network_sweep.sh - Network sweep and reconnaissance workflow
# Automated workflow for network-based reconnaissance

workflow_network_sweep() {
    local target="$1"
    local depth="${2:-medium}"  # quick, medium, deep

    # Validate target
    if [ -z "$target" ]; then
        log_error "Target required (IP or CIDR)"
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
            total_steps=9
            ;;
    esac

    # Create workflow run
    local workflow_id=$(db_workflow_create "$project_id" "network_sweep" "$target" "$total_steps")

    log_workflow_start "Network Sweep" "$target"
    log_info "Depth: $depth ($total_steps steps)"

    local current_step=0

    # STEP 1: Host Discovery
    ((current_step++))
    log_workflow_step "$current_step" "$total_steps" "Host Discovery (Ping Sweep)"
    db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "Host Discovery"

    if check_and_install_tool "nmap" "sudo apt-get install -y nmap" true; then
        run_tool "nmap" "$target" "-sn" || log_warning "Host discovery failed"

        # Extract live hosts from output
        # TODO: Parse and add as targets
    fi

    # STEP 2: Port Scanning
    ((current_step++))
    log_workflow_step "$current_step" "$total_steps" "Port Scanning (Top 1000 ports)"
    db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "Port Scanning"

    if [ "$depth" == "quick" ]; then
        # Quick scan - top 100 ports
        run_tool "nmap" "$target" "-F" || log_warning "Quick port scan failed"
    else
        # Standard scan - top 1000 ports
        run_tool "nmap" "$target" || log_warning "Port scan failed"
    fi

    # STEP 3: Service Detection
    ((current_step++))
    log_workflow_step "$current_step" "$total_steps" "Service and Version Detection"
    db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "Service Detection"

    run_tool "nmap" "$target" "-sV" || log_warning "Service detection failed"

    # Medium and Deep only steps
    if [[ "$depth" == "medium" || "$depth" == "deep" ]]; then

        # STEP 4: OS Detection
        ((current_step++))
        log_workflow_step "$current_step" "$total_steps" "Operating System Detection"
        db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "OS Detection"

        run_tool "nmap" "$target" "-O" || log_warning "OS detection failed (requires root)"

        # STEP 5: Default Script Scan
        ((current_step++))
        log_workflow_step "$current_step" "$total_steps" "NSE Default Scripts"
        db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "NSE Scripts"

        run_tool "nmap" "$target" "-sC" || log_warning "NSE scripts failed"

        # STEP 6: Vulnerability Scripts
        ((current_step++))
        log_workflow_step "$current_step" "$total_steps" "Vulnerability Detection Scripts"
        db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "Vulnerability Detection"

        run_tool "nmap" "$target" "--script vuln" || log_warning "Vulnerability scripts failed"
    fi

    # Deep only steps
    if [ "$depth" == "deep" ]; then

        # STEP 7: Full Port Scan
        ((current_step++))
        log_workflow_step "$current_step" "$total_steps" "Full Port Scan (all 65535 ports)"
        db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "Full Port Scan"

        if check_and_install_tool "masscan" "sudo apt-get install -y masscan" true; then
            run_tool "masscan" "$target" "-p1-65535 --rate=1000" || log_warning "Masscan failed"
        fi

        # STEP 8: SMB Enumeration (if port 445 open)
        ((current_step++))
        log_workflow_step "$current_step" "$total_steps" "SMB Enumeration"
        db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "SMB Enumeration"

        # Check if SMB port is open
        if run_tool "nmap" "$target" "-p445 --open" | grep -q "445/tcp.*open"; then
            log_info "SMB port detected, running enum4linux"

            if check_and_install_tool "enum4linux" "sudo apt-get install -y enum4linux" true; then
                run_tool "enum4linux" "$target" "-a" || log_warning "enum4linux failed"
            fi
        else
            log_info "SMB port not open, skipping enumeration"
        fi

        # STEP 9: SNMP Enumeration (if port 161 open)
        ((current_step++))
        log_workflow_step "$current_step" "$total_steps" "SNMP Enumeration"
        db_workflow_update "$workflow_id" "$((current_step * 100 / total_steps))" "SNMP Enumeration"

        if run_tool "nmap" "$target" "-p161 --open" | grep -q "161/udp.*open"; then
            log_info "SNMP port detected, running snmpwalk"

            if check_and_install_tool "snmpwalk" "sudo apt-get install -y snmp" true; then
                run_tool "snmpwalk" "$target" "-c public -v1" || log_warning "snmpwalk failed"
            fi
        else
            log_info "SNMP port not open, skipping enumeration"
        fi
    fi

    # Workflow complete
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    db_workflow_complete "$workflow_id" "completed"
    log_workflow_complete "Network Sweep" "$duration"

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

    log_success "Network sweep workflow completed"
}

# Quick network sweep
workflow_network_quick() {
    workflow_network_sweep "$1" "quick"
}

# Medium network sweep
workflow_network_medium() {
    workflow_network_sweep "$1" "medium"
}

# Deep network sweep
workflow_network_deep() {
    workflow_network_sweep "$1" "deep"
}

# Interactive workflow launcher
workflow_network_interactive() {
    echo
    log_section "NETWORK SWEEP WORKFLOW"

    read -rp "${BRIGHT_BLUE}Target (IP or CIDR):${RESET} " target

    if [ -z "$target" ]; then
        log_error "Target required"
        return 1
    fi

    # Validate target
    if ! is_valid_ip "$target" && ! [[ "$target" =~ / ]]; then
        log_error "Invalid IP or CIDR notation"
        return 1
    fi

    echo
    echo "Select depth:"
    echo "  ${RED}[1]${RESET} ${BRIGHT_BLUE}Quick${RESET} - Basic port scan (3 steps, ~5 min)"
    echo "  ${RED}[2]${RESET} ${BRIGHT_BLUE}Medium${RESET} - Standard reconnaissance (6 steps, ~15 min)"
    echo "  ${RED}[3]${RESET} ${BRIGHT_BLUE}Deep${RESET} - Comprehensive scan (9 steps, ~45 min)"
    echo

    read -rp "${BRIGHT_BLUE}Choice${RESET}${BRIGHT_RED} \$${RESET} " depth_choice

    case "$depth_choice" in
        1)
            workflow_network_sweep "$target" "quick"
            ;;
        2)
            workflow_network_sweep "$target" "medium"
            ;;
        3)
            workflow_network_sweep "$target" "deep"
            ;;
        *)
            log_error "Invalid choice"
            return 1
            ;;
    esac
}

# Scan specific port across network
workflow_port_scan() {
    local target="$1"
    local port="$2"

    if [ -z "$target" ] || [ -z "$port" ]; then
        log_error "Usage: workflow_port_scan <target> <port>"
        return 1
    fi

    log_section "PORT SCAN: $port"

    run_tool "nmap" "$target" "-p$port --open"

    log_success "Port scan completed"
}

# Scan common services
workflow_service_scan() {
    local target="$1"
    local service="$2"

    local project_id=$(get_current_project)
    if [ -z "$project_id" ]; then
        log_error "No project loaded"
        return 1
    fi

    log_section "SERVICE SCAN: $service"

    case "$service" in
        web)
            log_info "Scanning web services (80, 443, 8080, 8443)"
            run_tool "nmap" "$target" "-p80,443,8080,8443 -sV"
            ;;
        ftp)
            log_info "Scanning FTP services (21)"
            run_tool "nmap" "$target" "-p21 -sV --script ftp-*"
            ;;
        ssh)
            log_info "Scanning SSH services (22)"
            run_tool "nmap" "$target" "-p22 -sV --script ssh-*"
            ;;
        smb)
            log_info "Scanning SMB services (139, 445)"
            run_tool "nmap" "$target" "-p139,445 -sV --script smb-*"
            ;;
        rdp)
            log_info "Scanning RDP services (3389)"
            run_tool "nmap" "$target" "-p3389 -sV --script rdp-*"
            ;;
        database)
            log_info "Scanning database services (1433, 3306, 5432)"
            run_tool "nmap" "$target" "-p1433,3306,5432 -sV"
            ;;
        *)
            log_error "Unknown service: $service"
            log_info "Available: web, ftp, ssh, smb, rdp, database"
            return 1
            ;;
    esac

    log_success "Service scan completed"
}
