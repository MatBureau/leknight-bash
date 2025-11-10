#!/bin/bash

# parsers.sh - Output parsers for various security tools
# Extracts findings, vulnerabilities, and data from tool outputs

# Parse Nmap output
parse_nmap_output() {
    local output_file="$1"
    local scan_id="$2"
    local project_id="$3"
    local target_id="$4"

    log_debug "Parsing Nmap output"

    # Extract open ports
    grep -E "^[0-9]+/tcp.*open" "$output_file" | while read -r line; do
        local port=$(echo "$line" | awk '{print $1}' | cut -d'/' -f1)
        local service=$(echo "$line" | awk '{print $3}')
        local version=$(echo "$line" | cut -d' ' -f4-)

        # Update target with port info
        sqlite3 "$DB_PATH" <<EOF
INSERT OR IGNORE INTO targets (project_id, ip, port, service)
SELECT project_id, ip, $port, '$service'
FROM targets WHERE id = $target_id;
EOF

        log_port_open "$port" "$service"

        # Create info-level finding for open port
        local title="Open port: $port ($service)"
        local description="Service: $service\nVersion: $version"
        db_finding_add "$scan_id" "$project_id" "$target_id" "info" "open-port" "$title" "$description" "$line"
    done

    # Check for vulnerabilities mentioned
    if grep -qi "vulnerable" "$output_file"; then
        local vuln_lines=$(grep -i "vulnerable" "$output_file")
        echo "$vuln_lines" | while read -r line; do
            db_finding_add "$scan_id" "$project_id" "$target_id" "medium" "vulnerability" "Potential vulnerability detected" "$line" "$line"
            log_finding "medium" "Potential vulnerability found"
        done
    fi

    # Extract OS detection
    if grep -q "OS:" "$output_file"; then
        local os_info=$(grep "OS:" "$output_file" | head -1)
        log_info "OS detected: $os_info"
        db_finding_add "$scan_id" "$project_id" "$target_id" "info" "os-detection" "OS Detected" "$os_info" "$os_info"
    fi
}

# Parse Nikto output
parse_nikto_output() {
    local output_file="$1"
    local scan_id="$2"
    local project_id="$3"
    local target_id="$4"

    log_debug "Parsing Nikto output"

    # Extract vulnerabilities (lines starting with +)
    grep "^+ " "$output_file" | while read -r line; do
        local severity="medium"

        # Determine severity based on keywords
        if echo "$line" | grep -qiE "sql|xss|injection|rce|remote code"; then
            severity="high"
        elif echo "$line" | grep -qiE "disclosure|exposed|leak"; then
            severity="medium"
        elif echo "$line" | grep -qiE "outdated|version"; then
            severity="low"
        else
            severity="info"
        fi

        local title=$(echo "$line" | sed 's/^+ //' | cut -c1-100)
        local description="$line"

        db_finding_add "$scan_id" "$project_id" "$target_id" "$severity" "web-vulnerability" "$title" "$description" "$line"
        log_finding "$severity" "$title"
    done

    # Count total findings
    local finding_count=$(grep -c "^+ " "$output_file")
    log_info "Found $finding_count issues in Nikto scan"
}

# Parse Nuclei output
parse_nuclei_output() {
    local output_file="$1"
    local scan_id="$2"
    local project_id="$3"
    local target_id="$4"

    log_debug "Parsing Nuclei output"

    # Nuclei uses colored output, need to strip ANSI codes
    local clean_file="${output_file}.clean"
    sed 's/\x1b\[[0-9;]*m//g' "$output_file" > "$clean_file"

    # Parse findings (format: [severity] [template-id] url)
    grep -E "\[(critical|high|medium|low|info)\]" "$clean_file" | while read -r line; do
        local severity=$(echo "$line" | grep -oE "\[(critical|high|medium|low|info)\]" | tr -d '[]' | head -1)
        local template=$(echo "$line" | awk '{print $2}')
        local url=$(echo "$line" | awk '{print $3}')

        local title="$template"
        local description="Template matched: $template\nURL: $url"

        db_finding_add "$scan_id" "$project_id" "$target_id" "$severity" "nuclei-template" "$title" "$description" "$line"
        log_finding "$severity" "$title"
    done

    rm -f "$clean_file"
}

# Parse SQLMap output
parse_sqlmap_output() {
    local output_file="$1"
    local scan_id="$2"
    local project_id="$3"
    local target_id="$4"

    log_debug "Parsing SQLMap output"

    # Check if SQL injection was found
    if grep -qi "vulnerable" "$output_file" || grep -qi "sqlmap identified" "$output_file"; then
        local vuln_type=$(grep -oE "Type: [A-Z ]+" "$output_file" | head -1)
        local payload=$(grep -A5 "Payload:" "$output_file" | head -5 | tr '\n' ' ')

        local title="SQL Injection vulnerability found"
        local description="Type: $vuln_type\nPayload: $payload"

        db_finding_add "$scan_id" "$project_id" "$target_id" "critical" "sql-injection" "$title" "$description" "$vuln_type"
        log_finding "critical" "SQL Injection detected"

        # Extract database info if available
        if grep -q "back-end DBMS:" "$output_file"; then
            local dbms=$(grep "back-end DBMS:" "$output_file" | head -1)
            log_info "$dbms"
        fi

        # Extract dumped data (credentials)
        if grep -q "Database:" "$output_file"; then
            grep -A20 "Database:" "$output_file" | while read -r line; do
                if echo "$line" | grep -qE "[a-zA-Z0-9_]+\|[^ ]+"; then
                    local username=$(echo "$line" | awk -F'|' '{print $1}' | tr -d ' ')
                    local password=$(echo "$line" | awk -F'|' '{print $2}' | tr -d ' ')

                    if [ -n "$username" ] && [ -n "$password" ]; then
                        db_credential_add "$project_id" "$target_id" "$username" "$password" "" "" "database" "sqlmap"
                        log_credential "$username" "database"
                    fi
                fi
            done
        fi
    else
        log_info "No SQL injection vulnerabilities found"
    fi
}

# Parse WPScan output
parse_wpscan_output() {
    local output_file="$1"
    local scan_id="$2"
    local project_id="$3"
    local target_id="$4"

    log_debug "Parsing WPScan output"

    # Extract WordPress version
    if grep -q "WordPress version" "$output_file"; then
        local wp_version=$(grep "WordPress version" "$output_file" | head -1)
        db_finding_add "$scan_id" "$project_id" "$target_id" "info" "wordpress-version" "WordPress Version" "$wp_version" "$wp_version"
    fi

    # Extract vulnerable plugins
    grep -A5 "\[!\].*vulnerable" "$output_file" | while read -r line; do
        if echo "$line" | grep -q "\[!\]"; then
            local title=$(echo "$line" | sed 's/\[!\]//' | tr -d ' \t' | cut -c1-100)
            db_finding_add "$scan_id" "$project_id" "$target_id" "high" "vulnerable-plugin" "$title" "$line" "$line"
            log_finding "high" "Vulnerable plugin: $title"
        fi
    done

    # Extract usernames
    grep -oE "Username: [a-zA-Z0-9_-]+" "$output_file" | while read -r line; do
        local username=$(echo "$line" | awk '{print $2}')
        db_credential_add "$project_id" "$target_id" "$username" "" "" "" "wordpress" "wpscan"
        log_info "WordPress user found: $username"
    done
}

# Parse subdomain enumeration output (subfinder, amass, theHarvester)
parse_subdomain_output() {
    local output_file="$1"
    local scan_id="$2"
    local project_id="$3"
    local target_id="$4"

    log_debug "Parsing subdomain enumeration output"

    local subdomain_count=0

    # Get parent domain from target_id
    local parent_domain=$(sqlite3 "$DB_PATH" "SELECT hostname FROM targets WHERE id = $target_id LIMIT 1;" 2>/dev/null)

    # Read line by line and validate each subdomain
    while IFS= read -r subdomain; do
        # Clean the line
        subdomain=$(echo "$subdomain" | tr -d '\r\n\t ' | tr '[:upper:]' '[:lower:]')

        # Skip empty lines
        [ -z "$subdomain" ] && continue

        # Validate with the is_valid_domain function
        if ! is_valid_domain "$subdomain"; then
            log_debug "Skipping invalid domain: $subdomain"
            continue
        fi

        # CRITICAL FIX: Verify subdomain is actually a subdomain of parent domain
        if [ -n "$parent_domain" ]; then
            # Check if subdomain ends with .parent_domain or equals parent_domain
            if [[ "$subdomain" != *".${parent_domain}" ]] && [[ "$subdomain" != "${parent_domain}" ]]; then
                log_debug "Skipping unrelated domain: $subdomain (not a subdomain of $parent_domain)"
                continue
            fi
        fi

        # Check if already in database
        local existing=$(sqlite3 "$DB_PATH" "SELECT id FROM targets WHERE project_id = $project_id AND hostname = '$subdomain' LIMIT 1;")

        if [ -n "$existing" ]; then
            log_debug "Subdomain already exists: $subdomain"
            continue
        fi

        # Add as a new target
        local new_target_id=$(db_target_add "$project_id" "$subdomain" "" "" "" "subdomain")

        if [ -n "$new_target_id" ]; then
            ((subdomain_count++))
            log_target_discovered "$subdomain" "(subdomain)"

            # Create info finding
            db_finding_add "$scan_id" "$project_id" "$new_target_id" "info" "subdomain" "Subdomain discovered: $subdomain" "Found via subdomain enumeration" "$subdomain"
        fi
    done < "$output_file"

    log_success "Discovered $subdomain_count subdomains"
}

# Parse directory bruteforce output (ffuf, dirsearch, dirb)
parse_directory_output() {
    local output_file="$1"
    local scan_id="$2"
    local project_id="$3"
    local target_id="$4"

    log_debug "Parsing directory bruteforce output"

    # Extract found directories/files (typically lines with HTTP status codes)
    grep -oE "https?://[^ ]+" "$output_file" | while read -r url; do
        local path=$(echo "$url" | sed 's|^https\?://[^/]*/|/|')

        # Determine severity based on path
        local severity="info"
        if echo "$path" | grep -qiE "admin|backup|config|\.env|\.git|\.sql|\.zip"; then
            severity="medium"
        fi

        local title="Directory/File found: $path"
        db_finding_add "$scan_id" "$project_id" "$target_id" "$severity" "directory-found" "$title" "URL: $url" "$url"

        if [ "$severity" = "medium" ]; then
            log_finding "$severity" "$title"
        fi
    done
}

# Parse Hydra output (password bruteforce)
parse_hydra_output() {
    local output_file="$1"
    local scan_id="$2"
    local project_id="$3"
    local target_id="$4"

    log_debug "Parsing Hydra output"

    # Extract successful logins
    grep "\[.*\]\[.*\] host:" "$output_file" | while read -r line; do
        local service=$(echo "$line" | grep -oE "\[[a-z]+\]" | head -1 | tr -d '[]')
        local username=$(echo "$line" | grep -oE "login: [^ ]+" | awk '{print $2}')
        local password=$(echo "$line" | grep -oE "password: [^ ]+" | awk '{print $2}')

        if [ -n "$username" ] && [ -n "$password" ]; then
            db_credential_add "$project_id" "$target_id" "$username" "$password" "" "" "$service" "hydra"
            log_credential "$username" "$service"

            db_finding_add "$scan_id" "$project_id" "$target_id" "critical" "weak-credentials" "Weak credentials: $username" "Service: $service\nPassword: [REDACTED]" "$line"
            log_finding "critical" "Weak credentials found for $username"
        fi
    done
}

# Parse hashcat/john output (password cracking)
parse_hashcrack_output() {
    local output_file="$1"
    local scan_id="$2"
    local project_id="$3"
    local target_id="$4"

    log_debug "Parsing password cracking output"

    # Hashcat format: hash:password
    grep -E "^[a-f0-9]+:" "$output_file" | while read -r line; do
        local hash=$(echo "$line" | cut -d':' -f1)
        local password=$(echo "$line" | cut -d':' -f2-)

        db_credential_add "$project_id" "$target_id" "unknown" "$password" "$hash" "unknown" "cracked" "hashcat"
        log_credential "hash" "cracked"
    done

    # John format: username:password
    grep -E "^[^:]+:[^:]+$" "$output_file" | while read -r line; do
        local username=$(echo "$line" | cut -d':' -f1)
        local password=$(echo "$line" | cut -d':' -f2)

        db_credential_add "$project_id" "$target_id" "$username" "$password" "" "" "cracked" "john"
        log_credential "$username" "cracked"
    done
}

# Generic credential extractor
extract_credentials() {
    local output_file="$1"
    local scan_id="$2"
    local project_id="$3"
    local target_id="$4"

    log_debug "Extracting credentials from output"

    # Look for common credential patterns
    # Format: username:password, user=x password=y, etc.

    # Pattern 1: username:password
    grep -oE "[a-zA-Z0-9_.-]+:[a-zA-Z0-9!@#$%^&*()_+=-]+" "$output_file" | while read -r cred; do
        local username=$(echo "$cred" | cut -d':' -f1)
        local password=$(echo "$cred" | cut -d':' -f2)

        # Skip if looks like URL or port
        echo "$username" | grep -qE "^(http|https|ftp)" && continue
        echo "$password" | grep -qE "^[0-9]+$" && continue

        db_credential_add "$project_id" "$target_id" "$username" "$password" "" "" "extracted" "auto"
        log_credential "$username" "extracted"
    done
}

# Extract IP addresses from output
extract_ips() {
    local output_file="$1"
    local project_id="$2"

    grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" "$output_file" | sort -u | while read -r ip; do
        is_valid_ip "$ip" || continue

        # Check if IP already exists
        local existing=$(sqlite3 "$DB_PATH" "SELECT id FROM targets WHERE project_id = $project_id AND ip = '$ip' LIMIT 1;")

        if [ -z "$existing" ]; then
            project_add_target "$project_id" "$ip"
            log_target_discovered "$ip" "(IP address)"
        fi
    done
}

# Extract domains from output
extract_domains() {
    local output_file="$1"
    local project_id="$2"

    grep -oE "\b([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}\b" "$output_file" | \
    sort -u | while read -r domain; do
        is_valid_domain "$domain" || continue

        # Check if domain already exists
        local existing=$(sqlite3 "$DB_PATH" "SELECT id FROM targets WHERE project_id = $project_id AND hostname = '$domain' LIMIT 1;")

        if [ -z "$existing" ]; then
            project_add_target "$project_id" "$domain"
            log_target_discovered "$domain" "(domain)"
        fi
    done
}

# Extract URLs from output
extract_urls() {
    local output_file="$1"
    local scan_id="$2"
    local project_id="$3"
    local target_id="$4"

    grep -oE "https?://[a-zA-Z0-9./?=_%:-]*" "$output_file" | sort -u | while read -r url; do
        # Create info finding for URL
        db_finding_add "$scan_id" "$project_id" "$target_id" "info" "url-found" "URL discovered" "$url" "$url"
    done
}

# Extract email addresses
extract_emails() {
    local output_file="$1"
    local project_id="$2"

    grep -oE "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b" "$output_file" | \
    sort -u | while read -r email; do
        local username=$(echo "$email" | cut -d'@' -f1)
        local domain=$(echo "$email" | cut -d'@' -f2)

        # Store as credential
        db_credential_add "$project_id" "" "$email" "" "" "" "email" "extracted"
        log_info "Email found: $email"
    done
}

# Smart parser - tries to detect tool and parse accordingly
smart_parse() {
    local output_file="$1"
    local scan_id="$2"
    local project_id="$3"
    local target_id="$4"

    # Try to detect tool from output
    if grep -q "Nmap scan report" "$output_file"; then
        parse_nmap_output "$output_file" "$scan_id" "$project_id" "$target_id"
    elif grep -q "Nikto v" "$output_file"; then
        parse_nikto_output "$output_file" "$scan_id" "$project_id" "$target_id"
    elif grep -q "nuclei" "$output_file"; then
        parse_nuclei_output "$output_file" "$scan_id" "$project_id" "$target_id"
    elif grep -q "sqlmap" "$output_file"; then
        parse_sqlmap_output "$output_file" "$scan_id" "$project_id" "$target_id"
    else
        # Generic extraction
        log_debug "Using generic parsers"
        extract_credentials "$output_file" "$scan_id" "$project_id" "$target_id"
        extract_urls "$output_file" "$scan_id" "$project_id" "$target_id"
        extract_ips "$output_file" "$project_id"
        extract_domains "$output_file" "$project_id"
    fi
}
