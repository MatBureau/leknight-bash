#!/bin/bash

# wrapper.sh - Tool execution wrapper for LeKnight
# Captures output, parses results, and stores in database

# Execute a tool and capture results
run_tool() {
    local tool_name="$1"
    local target="$2"
    shift 2
    local additional_args="$@"

    # Get current project
    local project_id=$(get_current_project)
    if [ -z "$project_id" ]; then
        log_error "No project loaded. Use 'project load <id>' first"
        return 1
    fi

    # Check if tool exists
    if ! command_exists "$tool_name"; then
        log_error "$tool_name is not installed"
        return 1
    fi

    # Create output file
    local output_file=$(get_output_filename "$project_id" "$tool_name" "$target")
    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"

    # Get or create target ID
    local target_id=$(get_or_create_target "$project_id" "$target")

    # Build command based on tool
    local command=$(build_tool_command "$tool_name" "$target" "$additional_args")

    # Log tool start
    log_tool_start "$tool_name" "$target"

    # Create scan entry in database
    local scan_id=$(db_scan_create "$project_id" "$target_id" "$tool_name" "$command" "$output_file")

    # Execute tool and capture output
    local start_time=$(date +%s)

    # Run command and capture both stdout and stderr
    eval "$command" 2>&1 | tee "$output_file"
    local exit_code=${PIPESTATUS[0]}

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Update scan in database
    db_scan_complete "$scan_id" "$exit_code"

    # Log completion
    log_tool_complete "$tool_name" "$exit_code"
    log_file_saved "$output_file" "$(format_size $(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo 0))"

    # Parse results if tool completed successfully
    if [ "$exit_code" -eq 0 ]; then
        log_info "Parsing results from $tool_name..."
        parse_tool_output "$tool_name" "$output_file" "$scan_id" "$project_id" "$target_id"
    fi

    return "$exit_code"
}

# Get or create target entry
get_or_create_target() {
    local project_id="$1"
    local target="$2"

    # Check if target already exists
    local target_id=$(sqlite3 "$DB_PATH" <<EOF
SELECT id FROM targets
WHERE project_id = $project_id
AND (hostname = '$target' OR ip = '$target')
LIMIT 1;
EOF
)

    if [ -n "$target_id" ]; then
        echo "$target_id"
    else
        # Create new target
        project_add_target "$project_id" "$target"
    fi
}

# Build tool-specific command
build_tool_command() {
    local tool="$1"
    local target="$2"
    local args="$3"

    case "$tool" in
        nmap)
            if [ -n "$args" ]; then
                echo "nmap $args $target"
            else
                echo "nmap -sV -sC -O $target"
            fi
            ;;
        nikto)
            echo "nikto -h $target $args"
            ;;
        nuclei)
            echo "nuclei -u $target $args"
            ;;
        whatweb)
            echo "whatweb $target $args"
            ;;
        subfinder)
            echo "subfinder -d $target $args"
            ;;
        amass)
            echo "amass enum -d $target $args"
            ;;
        ffuf)
            if [ -n "$args" ]; then
                echo "ffuf $args"
            else
                echo "ffuf -u ${target}/FUZZ -w /usr/share/wordlists/dirb/common.txt $args"
            fi
            ;;
        sqlmap)
            echo "sqlmap -u $target --batch --random-agent $args"
            ;;
        dirsearch)
            echo "dirsearch -u $target $args"
            ;;
        wpscan)
            echo "wpscan --url $target --enumerate vp,vt,u $args"
            ;;
        masscan)
            if [ -n "$args" ]; then
                echo "sudo masscan $target $args"
            else
                echo "sudo masscan $target -p1-65535 --rate=1000 $args"
            fi
            ;;
        theHarvester)
            echo "theHarvester -d $target -b all $args"
            ;;
        dnsenum)
            echo "dnsenum $target $args"
            ;;
        hydra)
            echo "hydra $args $target"
            ;;
        *)
            # Generic command
            echo "$tool $target $args"
            ;;
    esac
}

# Parse tool output and extract findings
parse_tool_output() {
    local tool="$1"
    local output_file="$2"
    local scan_id="$3"
    local project_id="$4"
    local target_id="$5"

    if [ ! -f "$output_file" ]; then
        log_warning "Output file not found: $output_file"
        return 1
    fi

    case "$tool" in
        nmap)
            parse_nmap_output "$output_file" "$scan_id" "$project_id" "$target_id"
            ;;
        nikto)
            parse_nikto_output "$output_file" "$scan_id" "$project_id" "$target_id"
            ;;
        nuclei)
            parse_nuclei_output "$output_file" "$scan_id" "$project_id" "$target_id"
            ;;
        sqlmap)
            parse_sqlmap_output "$output_file" "$scan_id" "$project_id" "$target_id"
            ;;
        wpscan)
            parse_wpscan_output "$output_file" "$scan_id" "$project_id" "$target_id"
            ;;
        subfinder|amass|theHarvester)
            parse_subdomain_output "$output_file" "$scan_id" "$project_id" "$target_id"
            ;;
        *)
            log_debug "No specific parser for $tool, storing raw output"
            ;;
    esac

    log_success "Results parsed and stored"
}

# Quick scan wrapper for common scenarios
quick_scan() {
    local scan_type="$1"
    local target="$2"

    case "$scan_type" in
        web)
            log_info "Running quick web scan on $target"
            run_tool "whatweb" "$target"
            run_tool "nikto" "$target"
            ;;
        ports)
            log_info "Running quick port scan on $target"
            run_tool "nmap" "$target" "-F"
            ;;
        full)
            log_info "Running full scan on $target"
            run_tool "nmap" "$target"
            run_tool "whatweb" "$target"
            run_tool "nikto" "$target"
            ;;
        *)
            log_error "Unknown scan type: $scan_type"
            log_info "Available types: web, ports, full"
            return 1
            ;;
    esac
}

# Batch scan multiple targets
batch_scan() {
    local tool="$1"
    shift
    local targets=("$@")

    local project_id=$(get_current_project)
    if [ -z "$project_id" ]; then
        log_error "No project loaded"
        return 1
    fi

    log_section "BATCH SCAN: $tool"
    log_info "Targets: ${#targets[@]}"

    local success=0
    local failed=0

    for target in "${targets[@]}"; do
        echo
        log_info "[$((success + failed + 1))/${#targets[@]}] Scanning: $target"

        if run_tool "$tool" "$target"; then
            ((success++))
        else
            ((failed++))
        fi
    done

    echo
    log_success "Batch scan complete: $success succeeded, $failed failed"
}

# Scan from file
scan_from_file() {
    local tool="$1"
    local file="$2"

    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        return 1
    fi

    local targets=()
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        targets+=("$line")
    done < "$file"

    if [ ${#targets[@]} -eq 0 ]; then
        log_error "No targets found in file"
        return 1
    fi

    batch_scan "$tool" "${targets[@]}"
}

# Automated scanning based on target type
auto_scan() {
    local target="$1"

    log_section "AUTO SCAN: $target"

    # Detect target type
    if is_valid_ip "$target"; then
        log_info "Detected IP address"
        log_info "Running network scans..."

        run_tool "nmap" "$target" "-sV -sC"

        # Check for common web ports
        if grep -qE "80/tcp.*open|443/tcp.*open|8080/tcp.*open" "$output_file" 2>/dev/null; then
            log_info "Web services detected, running web scans..."
            local protocol="http"
            grep -q "443/tcp.*open" "$output_file" && protocol="https"

            run_tool "whatweb" "${protocol}://${target}"
            run_tool "nikto" "${protocol}://${target}"
        fi

    elif is_valid_domain "$target"; then
        log_info "Detected domain name"
        log_info "Running domain enumeration..."

        run_tool "subfinder" "$target"
        run_tool "whatweb" "https://${target}"
        run_tool "nikto" "https://${target}"

    elif is_valid_url "$target"; then
        log_info "Detected URL"
        log_info "Running web application scans..."

        run_tool "whatweb" "$target"
        run_tool "nikto" "$target"
        run_tool "nuclei" "$target"

    else
        log_error "Unable to determine target type: $target"
        return 1
    fi

    log_success "Auto scan completed for $target"
}

# Resume failed scans
resume_failed_scans() {
    local project_id=$(get_current_project)
    if [ -z "$project_id" ]; then
        log_error "No project loaded"
        return 1
    fi

    log_section "RESUMING FAILED SCANS"

    # Get failed scans
    local failed_scans=$(sqlite3 "$DB_PATH" <<EOF
SELECT id, tool, command FROM scans
WHERE project_id = $project_id
AND status = 'failed'
ORDER BY started_at DESC;
EOF
)

    if [ -z "$failed_scans" ]; then
        log_info "No failed scans found"
        return 0
    fi

    echo "$failed_scans" | while IFS='|' read -r scan_id tool command; do
        log_info "Retrying: $tool"
        echo "Command: $command"

        if confirm "Retry this scan?" "y"; then
            eval "$command"
            local exit_code=$?
            db_scan_complete "$scan_id" "$exit_code"

            if [ "$exit_code" -eq 0 ]; then
                log_success "Scan succeeded"
            else
                log_error "Scan failed again"
            fi
        fi
    done
}

# Schedule scan for later (simple implementation)
schedule_scan() {
    local tool="$1"
    local target="$2"
    local delay_minutes="${3:-60}"

    local schedule_file="${LEKNIGHT_ROOT}/data/.scheduled_scans"
    local scheduled_time=$(date -d "+${delay_minutes} minutes" '+%Y-%m-%d %H:%M:%S')

    echo "$scheduled_time|$tool|$target" >> "$schedule_file"

    log_success "Scan scheduled for $scheduled_time"
}

# Check and run scheduled scans
run_scheduled_scans() {
    local schedule_file="${LEKNIGHT_ROOT}/data/.scheduled_scans"

    if [ ! -f "$schedule_file" ]; then
        return 0
    fi

    local current_time=$(date +%s)

    while IFS='|' read -r scheduled_time tool target; do
        local scheduled_timestamp=$(date -d "$scheduled_time" +%s 2>/dev/null || echo 0)

        if [ "$current_time" -ge "$scheduled_timestamp" ]; then
            log_info "Running scheduled scan: $tool on $target"
            run_tool "$tool" "$target"

            # Remove from schedule
            sed -i "\|$scheduled_time|$tool|$target|d" "$schedule_file"
        fi
    done < "$schedule_file"
}
