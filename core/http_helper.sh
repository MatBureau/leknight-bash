#!/bin/bash

# HTTP Helper - Utilities for HTTP requests with project User-Agent support

source "$(dirname "${BASH_SOURCE[0]}")/database.sh"

# Get User-Agent for current project
get_project_user_agent() {
    local project_id="${1:-$(get_current_project)}"

    if [ -n "$project_id" ]; then
        db_get_user_agent "$project_id"
    else
        # Default User-Agent if no project
        echo "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    fi
}

# Project-aware curl wrapper
project_curl() {
    local project_id="${CURRENT_PROJECT_ID:-$(get_current_project)}"
    local user_agent=$(get_project_user_agent "$project_id")

    # Execute curl with project User-Agent
    curl -A "$user_agent" "$@"
}

# Project-aware curl for vulnerability testing
vuln_curl() {
    local project_id="${1}"
    shift
    local user_agent=$(get_project_user_agent "$project_id")

    # Execute curl with project User-Agent and common vulnerability testing flags
    curl -s -L -A "$user_agent" "$@"
}

# Export functions
export -f get_project_user_agent
export -f project_curl
export -f vuln_curl
