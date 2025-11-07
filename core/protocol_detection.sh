#!/bin/bash

# protocol_detection.sh - Automatic protocol detection for targets
# Detects whether a target supports HTTPS, HTTP, or both

# Detect best protocol for a domain
detect_protocol() {
    local domain="$1"
    local timeout="${2:-5}"  # Default 5 second timeout

    # If domain already contains protocol, extract and return it
    if echo "$domain" | grep -qE "^https://"; then
        log_debug "Domain already has HTTPS protocol specified"
        echo "https"
        return 0
    elif echo "$domain" | grep -qE "^http://"; then
        log_debug "Domain already has HTTP protocol specified"
        echo "http"
        return 0
    fi

    log_debug "Detecting protocol for $domain..."

    # Try HTTPS first (more secure)
    if curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "https://${domain}" 2>/dev/null | grep -qE "^(200|301|302|401|403)"; then
        log_debug "HTTPS works for $domain"
        echo "https"
        return 0
    fi

    # Fallback to HTTP
    if curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "http://${domain}" 2>/dev/null | grep -qE "^(200|301|302|401|403)"; then
        log_debug "HTTP works for $domain (HTTPS failed)"
        echo "http"
        return 0
    fi

    # Neither works, default to HTTPS anyway
    log_debug "Neither HTTP nor HTTPS responded, defaulting to HTTPS"
    echo "https"
    return 1
}

# Get full URL with protocol detection
get_target_url() {
    local target="$1"

    # If already has protocol, return as-is
    if echo "$target" | grep -qE "^https?://"; then
        echo "$target"
        return 0
    fi

    # Detect protocol
    local protocol=$(detect_protocol "$target")
    echo "${protocol}://${target}"
}

# Quick port check (faster than curl)
check_port_open() {
    local host="$1"
    local port="$2"
    local timeout="${3:-2}"

    # Use timeout with /dev/tcp for quick check
    timeout "$timeout" bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null
    return $?
}

# Smart protocol detection using port check + HTTP test
smart_detect_protocol() {
    local domain="$1"

    log_debug "Smart protocol detection for $domain..."

    # Check if port 443 is open
    if check_port_open "$domain" 443 2; then
        log_debug "Port 443 open, trying HTTPS..."
        if curl -s -o /dev/null --max-time 3 "https://${domain}" 2>/dev/null; then
            echo "https"
            return 0
        fi
    fi

    # Check if port 80 is open
    if check_port_open "$domain" 80 2; then
        log_debug "Port 80 open, using HTTP..."
        echo "http"
        return 0
    fi

    # Default to HTTPS if no ports respond
    log_debug "No ports responded, defaulting to HTTPS"
    echo "https"
    return 1
}
