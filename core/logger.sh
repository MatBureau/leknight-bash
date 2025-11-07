#!/bin/bash

# logger.sh - Logging system for LeKnight
# Provides colored logging with multiple levels and file output

# Log file location
LOG_FILE="${LEKNIGHT_ROOT}/data/logs/leknight.log"
LOG_LEVEL="${LEKNIGHT_LOG_LEVEL:-INFO}"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Color definitions (reuse from main)
RESET="${RESET:-$(tput sgr0)}"
BOLD="${BOLD:-$(tput bold)}"
RED="${RED:-$(tput setaf 5)}"
BLUE="${BLUE:-$(tput setaf 7)}"
GRAY="${GRAY:-$(tput setaf 8)}"
BRIGHT_RED="${BRIGHT_RED:-${BOLD}$(tput setaf 3)}"
BRIGHT_BLUE="${BRIGHT_BLUE:-${BOLD}$(tput setaf 7)}"
GREEN="${GREEN:-$(tput setaf 2)}"
YELLOW="${YELLOW:-$(tput setaf 3)}"

# Log level priorities
declare -A LOG_PRIORITIES=(
    [DEBUG]=0
    [INFO]=1
    [SUCCESS]=2
    [WARNING]=3
    [ERROR]=4
    [CRITICAL]=5
)

# Get current log level priority
get_log_priority() {
    echo "${LOG_PRIORITIES[$1]}"
}

# Check if message should be logged
should_log() {
    local msg_level="$1"
    local current_priority=$(get_log_priority "$LOG_LEVEL")
    local msg_priority=$(get_log_priority "$msg_level")

    [ "$msg_priority" -ge "$current_priority" ]
}

# Core logging function
_log() {
    local level="$1"
    local color="$2"
    local symbol="$3"
    shift 3
    local message="$*"

    # Check if should log this level
    if ! should_log "$level"; then
        return 0
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"

    # Write to log file
    echo "$log_entry" >> "$LOG_FILE"

    # Print to console with color
    echo -e "${color}[${symbol}]${RESET} ${message}"
}

# Logging functions
log_debug() {
    _log "DEBUG" "$GRAY" "·" "$@"
}

log_info() {
    _log "INFO" "$BLUE" "i" "$@"
}

log_success() {
    _log "SUCCESS" "$GREEN" "✓" "$@"
}

log_warning() {
    _log "WARNING" "$YELLOW" "!" "$@"
}

log_error() {
    _log "ERROR" "$RED" "✗" "$@"
}

log_critical() {
    _log "CRITICAL" "$BRIGHT_RED" "⚠" "$@"
}

# Alias for compatibility
log_warn() {
    log_warning "$@"
}

# Special logging for tool execution
log_tool_start() {
    local tool="$1"
    local target="$2"
    _log "INFO" "$BRIGHT_BLUE" "◆" "Starting ${BRIGHT_BLUE}${tool}${RESET} on ${BRIGHT_BLUE}${target}${RESET}"
}

log_tool_complete() {
    local tool="$1"
    local exit_code="$2"

    if [ "$exit_code" -eq 0 ]; then
        _log "SUCCESS" "$GREEN" "✓" "${tool} completed successfully"
    else
        _log "ERROR" "$RED" "✗" "${tool} failed with exit code $exit_code"
    fi
}

# Log finding discovery
log_finding() {
    local severity="$1"
    local title="$2"

    case "$severity" in
        critical)
            _log "CRITICAL" "$BRIGHT_RED" "🔥" "[CRITICAL] $title"
            ;;
        high)
            _log "ERROR" "$RED" "⚡" "[HIGH] $title"
            ;;
        medium)
            _log "WARNING" "$YELLOW" "◆" "[MEDIUM] $title"
            ;;
        low)
            _log "INFO" "$BLUE" "·" "[LOW] $title"
            ;;
        info)
            _log "INFO" "$GRAY" "i" "[INFO] $title"
            ;;
    esac
}

# Log credential discovery
log_credential() {
    local username="$1"
    local service="$2"
    _log "SUCCESS" "$GREEN" "🔑" "Credential found: ${username}@${service}"
}

# Workflow logging
log_workflow_start() {
    local workflow="$1"
    local target="$2"
    echo
    echo -e "${BRIGHT_RED}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BRIGHT_RED}║${RESET}  ${BRIGHT_BLUE}Workflow: ${workflow}${RESET}"
    echo -e "${BRIGHT_RED}║${RESET}  ${BRIGHT_BLUE}Target: ${target}${RESET}"
    echo -e "${BRIGHT_RED}╚════════════════════════════════════════════════════════╝${RESET}"
    echo
    _log "INFO" "$BRIGHT_BLUE" "▶" "Starting workflow: $workflow"
}

log_workflow_step() {
    local step_num="$1"
    local total_steps="$2"
    local step_name="$3"
    echo
    echo -e "${BRIGHT_BLUE}[Step $step_num/$total_steps]${RESET} $step_name"
    _log "INFO" "$BLUE" "→" "Step $step_num/$total_steps: $step_name"
}

log_workflow_complete() {
    local workflow="$1"
    local duration="$2"
    echo
    echo -e "${BRIGHT_RED}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BRIGHT_RED}║${RESET}  ${GREEN}Workflow Complete: ${workflow}${RESET}"
    echo -e "${BRIGHT_RED}║${RESET}  ${BLUE}Duration: ${duration}s${RESET}"
    echo -e "${BRIGHT_RED}╚════════════════════════════════════════════════════════╝${RESET}"
    echo
    _log "SUCCESS" "$GREEN" "✓" "Workflow completed: $workflow (${duration}s)"
}

# Progress bar
log_progress() {
    local current="$1"
    local total="$2"
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))

    printf "\r${BRIGHT_BLUE}Progress:${RESET} ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%$((width - filled))s" | tr ' ' '░'
    printf "] %3d%%" "$percentage"

    if [ "$current" -eq "$total" ]; then
        echo
    fi
}

# Section headers
log_section() {
    local title="$1"
    echo
    echo -e "${BRIGHT_RED}═══════════════════════════════════════════════════════${RESET}"
    echo -e "${BRIGHT_BLUE}  $title${RESET}"
    echo -e "${BRIGHT_RED}═══════════════════════════════════════════════════════${RESET}"
    echo
}

# Command execution logging
log_command() {
    local cmd="$1"
    _log "DEBUG" "$GRAY" "$" "Executing: $cmd"
}

# File operation logging
log_file_created() {
    local filepath="$1"
    _log "INFO" "$BLUE" "📄" "Created: $filepath"
}

log_file_saved() {
    local filepath="$1"
    local size="$2"
    _log "SUCCESS" "$GREEN" "💾" "Saved: $filepath ($size)"
}

# Network operation logging
log_target_discovered() {
    local target="$1"
    local info="$2"
    _log "INFO" "$BRIGHT_BLUE" "🎯" "Target discovered: $target $info"
}

log_port_open() {
    local port="$1"
    local service="$2"
    _log "INFO" "$BLUE" "🔓" "Open port: $port ($service)"
}

# Cleanup old logs
log_cleanup() {
    local days="${1:-7}"
    local log_dir="$(dirname "$LOG_FILE")"

    find "$log_dir" -name "*.log" -type f -mtime +$days -delete
    log_info "Cleaned up logs older than $days days"
}

# Rotate logs
log_rotate() {
    if [ -f "$LOG_FILE" ]; then
        local timestamp=$(date '+%Y%m%d_%H%M%S')
        local archive="${LOG_FILE}.${timestamp}"
        mv "$LOG_FILE" "$archive"
        gzip "$archive" 2>/dev/null || true
        log_info "Log rotated to ${archive}.gz"
    fi
}

# Get log statistics
log_stats() {
    if [ ! -f "$LOG_FILE" ]; then
        echo "No log file found"
        return
    fi

    echo "=== LOG STATISTICS ==="
    echo "Total entries: $(wc -l < "$LOG_FILE")"
    echo "Errors: $(grep -c "\[ERROR\]" "$LOG_FILE" 2>/dev/null || echo 0)"
    echo "Warnings: $(grep -c "\[WARNING\]" "$LOG_FILE" 2>/dev/null || echo 0)"
    echo "Critical: $(grep -c "\[CRITICAL\]" "$LOG_FILE" 2>/dev/null || echo 0)"
    echo "Success: $(grep -c "\[SUCCESS\]" "$LOG_FILE" 2>/dev/null || echo 0)"
}

# Tail logs in real-time
log_tail() {
    local lines="${1:-50}"
    tail -f -n "$lines" "$LOG_FILE"
}

# Search logs
log_search() {
    local query="$1"
    grep -i "$query" "$LOG_FILE" | tail -50
}

# Export logs to different formats
log_export_json() {
    local output="$1"
    awk '
    BEGIN { print "[" }
    {
        match($0, /\[(.*?)\] \[(.*?)\] (.*)/, arr)
        printf "%s{\"timestamp\":\"%s\",\"level\":\"%s\",\"message\":\"%s\"}",
               (NR>1?",":""), arr[1], arr[2], arr[3]
    }
    END { print "]" }
    ' "$LOG_FILE" > "$output"
}

# Show recent logs with color
log_show() {
    local lines="${1:-20}"
    tail -n "$lines" "$LOG_FILE" | while IFS= read -r line; do
        if [[ $line =~ \[ERROR\] ]]; then
            echo -e "${RED}$line${RESET}"
        elif [[ $line =~ \[WARNING\] ]]; then
            echo -e "${YELLOW}$line${RESET}"
        elif [[ $line =~ \[CRITICAL\] ]]; then
            echo -e "${BRIGHT_RED}$line${RESET}"
        elif [[ $line =~ \[SUCCESS\] ]]; then
            echo -e "${GREEN}$line${RESET}"
        elif [[ $line =~ \[INFO\] ]]; then
            echo -e "${BLUE}$line${RESET}"
        else
            echo -e "${GRAY}$line${RESET}"
        fi
    done
}
