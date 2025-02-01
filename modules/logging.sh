#!/bin/bash

# Logging and execution tracking module
# Features:
# - Multi-level logging (DEBUG, INFO, WARN, ERROR)
# - Log rotation and size management
# - Timestamp-based logging
# - Safe command execution with logging
# - Error tracking and reporting

# Add debug level control
readonly LOG_LEVEL=${LOG_LEVEL:-"INFO"}
readonly LOG_MAX_SIZE=$((10*1024*1024)) # 10MB

# Rotate log file when size exceeds threshold
rotate_log() {
    if [ -f "$LOG_FILE" ] && [ "$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE")" -gt "$LOG_MAX_SIZE" ]; then
        mv "$LOG_FILE" "$LOG_FILE.old"
    fi
}

# Write formatted log message with timestamp
log_message() {
    local level=$1
    local message=$2
    
    # Check if we should log this level
    case "$LOG_LEVEL" in
        "DEBUG") [[ "$level" == "DEBUG" ]] || return 0 ;;
        "INFO") [[ "$level" =~ ^(INFO|WARN|ERROR)$ ]] || return 0 ;;
        "WARN") [[ "$level" =~ ^(WARN|ERROR)$ ]] || return 0 ;;
        "ERROR") [[ "$level" == "ERROR" ]] || return 0 ;;
    esac

    rotate_log
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $level: $message" | tee -a "$LOG_FILE"
}

# Logging functions for different severity levels
log_debug() { log_message "DEBUG" "$1"; }
log_info() { log_message "INFO" "$1"; }
log_warn() { log_message "WARN" "$1" >&2; }
log_error() { log_message "ERROR" "$1" >&2; }

# Execute command with logging and error handling
execute_safely() {
    local cmd_name=$1
    shift
    log_info "Executing: $cmd_name $*"
    if ! "$cmd_name" "$@"; then
        log_error "Failed to execute: $cmd_name $*"
        return 1
    fi
}
