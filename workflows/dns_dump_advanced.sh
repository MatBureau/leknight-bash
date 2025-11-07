#!/bin/bash

# Advanced DNS Reconnaissance Module
# Comprehensive DNS enumeration with zone transfer, DNSSEC, SPF, DMARC, etc.

source "$(dirname "${BASH_SOURCE[0]}")/../core/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/database.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../core/parsers.sh"

# Main DNS dump function
dns_dump_advanced() {
    local domain=$1
    local project_id=$2

    log_section "Advanced DNS Reconnaissance"
    log_info "Target domain: $domain"

    local output_dir="data/projects/${project_id}/scans/dns"
    mkdir -p "$output_dir"

    local output_file="${output_dir}/dns_dump_${domain}.txt"

    {
        echo "========================================"
        echo "Advanced DNS Reconnaissance: $domain"
        echo "========================================"
        echo "Date: $(date)"
        echo ""

        # Phase 1: Standard DNS records
        dns_standard_records "$domain"

        # Phase 2: Email security records
        dns_email_security "$domain"

        # Phase 3: Zone transfer test
        dns_zone_transfer "$domain"

        # Phase 4: DNSSEC validation
        dns_dnssec_check "$domain"

        # Phase 5: Reverse DNS
        dns_reverse_lookup "$domain"

        # Phase 6: Subdomain discovery via DNS
        dns_subdomain_discovery "$domain" "$project_id"

        # Phase 7: CAA records (Certificate Authority Authorization)
        dns_caa_records "$domain"

        # Phase 8: TXT record analysis
        dns_txt_analysis "$domain"

        # Phase 9: NS and SOA analysis
        dns_nameserver_analysis "$domain"

    } | tee "$output_file"

    # Parse results and populate database
    parse_dns_dump "$output_file" "$project_id"

    # Generate DNS security report
    generate_dns_security_report "$domain" "$project_id" "$output_dir"

    log_success "DNS reconnaissance completed: $output_file"
}

# Phase 1: Standard DNS records
dns_standard_records() {
    local domain=$1

    log_info "[DNS] Phase 1: Standard DNS records"

    echo ""
    echo "=== A Records (IPv4) ==="
    dig +short A "$domain" | tee /dev/tty || echo "No A records found"

    echo ""
    echo "=== AAAA Records (IPv6) ==="
    dig +short AAAA "$domain" | tee /dev/tty || echo "No AAAA records found"

    echo ""
    echo "=== CNAME Records ==="
    dig +short CNAME "$domain" | tee /dev/tty || echo "No CNAME records found"

    echo ""
    echo "=== MX Records (Mail Servers) ==="
    dig +short MX "$domain" | tee /dev/tty || echo "No MX records found"

    echo ""
    echo "=== NS Records (Name Servers) ==="
    dig +short NS "$domain" | tee /dev/tty || echo "No NS records found"

    echo ""
    echo "=== TXT Records ==="
    dig +short TXT "$domain" | tee /dev/tty || echo "No TXT records found"

    echo ""
    echo "=== SOA Record (Start of Authority) ==="
    dig +short SOA "$domain" | tee /dev/tty || echo "No SOA record found"
}

# Phase 2: Email security records
dns_email_security() {
    local domain=$1

    log_info "[DNS] Phase 2: Email security configuration"

    echo ""
    echo "=== SPF Record (Sender Policy Framework) ==="
    local spf=$(dig +short TXT "$domain" | grep -i "v=spf")
    if [ -n "$spf" ]; then
        echo "$spf"
        analyze_spf "$spf"
    else
        echo "⚠️  No SPF record found - emails may be spoofed!"
    fi

    echo ""
    echo "=== DMARC Record ==="
    local dmarc=$(dig +short TXT "_dmarc.$domain")
    if [ -n "$dmarc" ]; then
        echo "$dmarc"
        analyze_dmarc "$dmarc"
    else
        echo "⚠️  No DMARC record found - no email authentication policy!"
    fi

    echo ""
    echo "=== DKIM Records ==="
    # Common DKIM selectors
    local dkim_selectors=("default" "google" "selector1" "selector2" "k1" "dkim" "mail" "email")
    local dkim_found=false

    for selector in "${dkim_selectors[@]}"; do
        local dkim=$(dig +short TXT "${selector}._domainkey.$domain" 2>/dev/null)
        if [ -n "$dkim" ] && echo "$dkim" | grep -qi "DKIM"; then
            echo "Selector: $selector"
            echo "$dkim"
            dkim_found=true
        fi
    done

    if [ "$dkim_found" = false ]; then
        echo "⚠️  No common DKIM selectors found"
    fi

    echo ""
    echo "=== BIMI Record (Brand Indicators for Message Identification) ==="
    dig +short TXT "default._bimi.$domain" || echo "No BIMI record found"
}

# Phase 3: Zone transfer test
dns_zone_transfer() {
    local domain=$1

    log_info "[DNS] Phase 3: Zone transfer test (AXFR)"

    echo ""
    echo "=== Zone Transfer Attempt ==="

    # Get authoritative nameservers
    local nameservers=$(dig +short NS "$domain")

    if [ -z "$nameservers" ]; then
        echo "No nameservers found"
        return 1
    fi

    echo "Trying zone transfer on nameservers:"
    echo "$nameservers"
    echo ""

    local transfer_success=false

    while read -r ns; do
        [ -z "$ns" ] && continue

        echo "Attempting zone transfer from: $ns"

        # Try AXFR (zone transfer)
        local result=$(dig @"$ns" "$domain" AXFR 2>&1)

        if echo "$result" | grep -qE "Transfer failed|connection timed out|failed"; then
            echo "✓ Protected - Zone transfer denied"
        else
            if echo "$result" | grep -qE "IN\s+(A|AAAA|CNAME|MX|TXT)"; then
                echo "🔴 VULNERABLE - Zone transfer successful!"
                echo "$result"
                transfer_success=true
            else
                echo "✓ Protected - Zone transfer denied"
            fi
        fi

        echo ""
    done <<< "$nameservers"

    if [ "$transfer_success" = true ]; then
        echo "⚠️  SECURITY ISSUE: Zone transfer is enabled!"
        echo "This exposes all DNS records and may reveal internal infrastructure"
    fi
}

# Phase 4: DNSSEC validation
dns_dnssec_check() {
    local domain=$1

    log_info "[DNS] Phase 4: DNSSEC validation"

    echo ""
    echo "=== DNSSEC Status ==="

    # Check for DNSKEY records
    local dnskey=$(dig +short DNSKEY "$domain")

    if [ -n "$dnskey" ]; then
        echo "✓ DNSSEC is enabled"
        echo ""
        echo "DNSKEY records:"
        echo "$dnskey"

        echo ""
        echo "RRSIG records:"
        dig +short RRSIG "$domain"

        echo ""
        echo "DS records:"
        dig +short DS "$domain"

        # Validate DNSSEC chain
        echo ""
        echo "DNSSEC validation:"
        dig "$domain" +dnssec +multiline | grep -E "ad|RRSIG"
    else
        echo "⚠️  DNSSEC is NOT enabled"
        echo "Domain is vulnerable to DNS spoofing attacks"
    fi
}

# Phase 5: Reverse DNS lookup
dns_reverse_lookup() {
    local domain=$1

    log_info "[DNS] Phase 5: Reverse DNS lookup"

    echo ""
    echo "=== Reverse DNS (PTR records) ==="

    # Get IP addresses
    local ips=$(dig +short A "$domain")

    if [ -z "$ips" ]; then
        echo "No IP addresses found"
        return 1
    fi

    while read -r ip; do
        [ -z "$ip" ] && continue

        echo "IP: $ip"
        local ptr=$(dig +short -x "$ip")

        if [ -n "$ptr" ]; then
            echo "  PTR: $ptr"

            # Check if PTR matches domain
            if echo "$ptr" | grep -qi "$domain"; then
                echo "  ✓ PTR record matches domain"
            else
                echo "  ⚠️  PTR record doesn't match domain (possible shared hosting)"
            fi
        else
            echo "  No PTR record"
        fi

        echo ""
    done <<< "$ips"
}

# Phase 6: Subdomain discovery via DNS
dns_subdomain_discovery() {
    local domain=$1
    local project_id=$2

    log_info "[DNS] Phase 6: Common subdomain enumeration"

    echo ""
    echo "=== Common Subdomains ==="

    # Common subdomains
    local subdomains=("www" "mail" "ftp" "admin" "webmail" "smtp" "pop" "imap" "test" "dev" "stage" "staging" "api" "app" "portal" "vpn" "remote" "blog" "shop" "forum" "support" "help" "docs" "cdn" "media" "static" "assets" "m" "mobile" "wap")

    local found_count=0

    for sub in "${subdomains[@]}"; do
        local full_domain="${sub}.${domain}"
        local result=$(dig +short A "$full_domain" 2>/dev/null)

        if [ -n "$result" ]; then
            echo "✓ Found: $full_domain → $result"
            found_count=$((found_count + 1))

            # Add to database
            db_execute "INSERT OR IGNORE INTO targets (project_id, hostname, ip, tag, autopilot_status) \
                        VALUES ($project_id, '$full_domain', '$result', 'dns_subdomain', 'pending')" 2>/dev/null
        fi
    done

    echo ""
    echo "Found $found_count subdomains"
}

# Phase 7: CAA records
dns_caa_records() {
    local domain=$1

    log_info "[DNS] Phase 7: CAA records (Certificate Authority Authorization)"

    echo ""
    echo "=== CAA Records ==="

    local caa=$(dig +short CAA "$domain")

    if [ -n "$caa" ]; then
        echo "$caa"
        echo ""
        echo "CAA records restrict which CAs can issue certificates for this domain"
    else
        echo "⚠️  No CAA records found"
        echo "Any CA can issue certificates for this domain"
    fi
}

# Phase 8: TXT record analysis
dns_txt_analysis() {
    local domain=$1

    log_info "[DNS] Phase 8: TXT record analysis"

    echo ""
    echo "=== TXT Record Analysis ==="

    local txt_records=$(dig +short TXT "$domain")

    if [ -z "$txt_records" ]; then
        echo "No TXT records found"
        return
    fi

    echo "$txt_records" | while read -r txt; do
        echo "Record: $txt"

        # Analyze content
        if echo "$txt" | grep -qi "v=spf"; then
            echo "  Type: SPF (Email authentication)"
        elif echo "$txt" | grep -qi "v=DMARC"; then
            echo "  Type: DMARC (Email policy)"
        elif echo "$txt" | grep -qi "google-site-verification"; then
            echo "  Type: Google Site Verification"
        elif echo "$txt" | grep -qi "MS="; then
            echo "  Type: Microsoft domain verification"
        elif echo "$txt" | grep -qi "facebook-domain-verification"; then
            echo "  Type: Facebook domain verification"
        else
            echo "  Type: Other/Unknown"

            # Check for sensitive information
            if echo "$txt" | grep -qiE "password|secret|key|token|api"; then
                echo "  ⚠️  WARNING: May contain sensitive information!"
            fi
        fi

        echo ""
    done
}

# Phase 9: Nameserver analysis
dns_nameserver_analysis() {
    local domain=$1

    log_info "[DNS] Phase 9: Nameserver and SOA analysis"

    echo ""
    echo "=== Nameserver Details ==="

    local nameservers=$(dig +short NS "$domain")

    if [ -z "$nameservers" ]; then
        echo "No nameservers found"
        return
    fi

    while read -r ns; do
        [ -z "$ns" ] && continue

        echo "Nameserver: $ns"

        # Get NS IP
        local ns_ip=$(dig +short A "$ns")
        echo "  IP: $ns_ip"

        # Query version (often disabled for security)
        local version=$(dig @"$ns" version.bind chaos txt +short 2>/dev/null)
        if [ -n "$version" ]; then
            echo "  Version: $version"
            echo "  ⚠️  WARNING: Nameserver version disclosure enabled"
        fi

        echo ""
    done <<< "$nameservers"

    echo ""
    echo "=== SOA Record Details ==="
    dig SOA "$domain" +multiline
}

# Helper: Analyze SPF record
analyze_spf() {
    local spf=$1

    # Check for common issues
    if echo "$spf" | grep -q "~all"; then
        echo "  Policy: Soft fail (~all) - weak protection"
    elif echo "$spf" | grep -q "-all"; then
        echo "  ✓ Policy: Hard fail (-all) - strict protection"
    elif echo "$spf" | grep -q "+all"; then
        echo "  ⚠️  Policy: Pass all (+all) - NO PROTECTION!"
    fi

    # Count DNS lookups (SPF has 10 lookup limit)
    local lookup_count=$(echo "$spf" | grep -o "include:" | wc -l)
    echo "  DNS lookups: $lookup_count"

    if [ "$lookup_count" -gt 10 ]; then
        echo "  ⚠️  WARNING: Exceeds 10 DNS lookup limit (SPF will fail)"
    fi
}

# Helper: Analyze DMARC record
analyze_dmarc() {
    local dmarc=$1

    # Extract policy
    local policy=$(echo "$dmarc" | grep -oP 'p=\K[^;]+')
    echo "  Policy: $policy"

    case "$policy" in
        "none")
            echo "  ⚠️  Monitor mode - no enforcement"
            ;;
        "quarantine")
            echo "  Moderate protection - suspicious emails quarantined"
            ;;
        "reject")
            echo "  ✓ Strong protection - failing emails rejected"
            ;;
    esac

    # Check for reporting
    if echo "$dmarc" | grep -q "rua="; then
        local rua=$(echo "$dmarc" | grep -oP 'rua=\K[^;]+')
        echo "  Aggregate reports: $rua"
    fi
}

# Parse DNS dump and extract findings
parse_dns_dump() {
    local file=$1
    local project_id=$2

    log_info "[DNS] Parsing DNS dump results"

    # Extract IP addresses
    grep -oP '\d+\.\d+\.\d+\.\d+' "$file" | sort -u | while read -r ip; do
        db_execute "INSERT OR IGNORE INTO targets (project_id, ip, tag, autopilot_status) \
                    VALUES ($project_id, '$ip', 'dns_discovered', 'pending')" 2>/dev/null
    done

    # Extract subdomains
    grep "Found:" "$file" | awk '{print $3}' | while read -r subdomain; do
        [ -z "$subdomain" ] && continue

        db_execute "INSERT OR IGNORE INTO targets (project_id, hostname, tag, autopilot_status) \
                    VALUES ($project_id, '$subdomain', 'dns_subdomain', 'pending')" 2>/dev/null
    done

    # Security findings

    # Check for zone transfer vulnerability
    if grep -q "VULNERABLE - Zone transfer successful" "$file"; then
        db_add_finding "$project_id" "high" "dns_zone_transfer" \
            "DNS Zone Transfer Enabled" \
            "The DNS server allows zone transfers (AXFR), exposing all DNS records.\n\nThis reveals internal infrastructure and potential attack targets." \
            "CWE-284" "7.5" \
            "1. Disable zone transfers or restrict to authorized secondaries only\n2. Configure allow-transfer in BIND or equivalent\n3. Example BIND config: allow-transfer { none; };"
    fi

    # Check for missing SPF
    if grep -q "No SPF record found" "$file"; then
        db_add_finding "$project_id" "medium" "dns_no_spf" \
            "Missing SPF Record" \
            "No SPF record found. Domain is vulnerable to email spoofing." \
            "CWE-346" "5.3" \
            "1. Implement SPF record\n2. Example: v=spf1 include:_spf.google.com ~all\n3. Test SPF record before deployment"
    fi

    # Check for missing DMARC
    if grep -q "No DMARC record found" "$file"; then
        db_add_finding "$project_id" "medium" "dns_no_dmarc" \
            "Missing DMARC Record" \
            "No DMARC record found. No email authentication policy defined." \
            "CWE-346" "5.3" \
            "1. Implement DMARC record\n2. Start with p=none for monitoring\n3. Example: v=DMARC1; p=none; rua=mailto:dmarc@example.com"
    fi

    # Check for missing DNSSEC
    if grep -q "DNSSEC is NOT enabled" "$file"; then
        db_add_finding "$project_id" "low" "dns_no_dnssec" \
            "DNSSEC Not Enabled" \
            "DNSSEC is not enabled. Domain is vulnerable to DNS spoofing/cache poisoning." \
            "CWE-345" "4.3" \
            "1. Enable DNSSEC on domain\n2. Add DS records to parent zone\n3. Monitor DNSSEC validation"
    fi
}

# Generate DNS security report
generate_dns_security_report() {
    local domain=$1
    local project_id=$2
    local output_dir=$3

    local report_file="${output_dir}/dns_security_report.txt"

    cat > "$report_file" <<EOF
================================================
DNS Security Report: $domain
================================================
Generated: $(date)

EOF

    # Email Security Score
    local spf_score=0
    local dmarc_score=0
    local dkim_score=0

    grep -q "v=spf" "${output_dir}/dns_dump_${domain}.txt" && spf_score=33
    grep -q "v=DMARC1" "${output_dir}/dns_dump_${domain}.txt" && dmarc_score=33
    grep -q "DKIM" "${output_dir}/dns_dump_${domain}.txt" && dkim_score=34

    local email_security_score=$((spf_score + dmarc_score + dkim_score))

    echo "Email Security Score: $email_security_score/100" >> "$report_file"
    echo "" >> "$report_file"

    # DNSSEC Status
    if grep -q "DNSSEC is enabled" "${output_dir}/dns_dump_${domain}.txt"; then
        echo "DNSSEC: ✓ Enabled" >> "$report_file"
    else
        echo "DNSSEC: ✗ Disabled" >> "$report_file"
    fi

    # Zone Transfer Status
    if grep -q "Zone transfer successful" "${output_dir}/dns_dump_${domain}.txt"; then
        echo "Zone Transfer: ✗ VULNERABLE" >> "$report_file"
    else
        echo "Zone Transfer: ✓ Protected" >> "$report_file"
    fi

    echo "" >> "$report_file"
    echo "Full details in: ${output_dir}/dns_dump_${domain}.txt" >> "$report_file"

    log_info "[DNS] Security report: $report_file"
}

# Export functions
export -f dns_dump_advanced
export -f parse_dns_dump
