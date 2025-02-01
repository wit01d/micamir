#!/bin/bash

# Resource cleanup and environment restoration module
# Handles:
# - Process termination
# - Temporary file cleanup
# - Module unloading
# - Phone environment cleanup
# - System resource release

# Clean up all resources and temporary files
cleanup() {
    log_info "Cleaning up resources"
    
    # Kill background processes
    kill $(jobs -p) 2>/dev/null
    
    # Remove temporary files
    rm -f "$DEFAULT_MIC_PIPE"
    
    # Unload modules
    sudo modprobe -r v4l2loopback 2>/dev/null
    
    # Cleanup phone environments
    for phone in "${!PHONE_CONFIGS[@]}"; do
        cleanup_phone_environment "$phone"
    done
    
    log_info "Cleanup complete"
}

# Clean up resources for specific phone environment
cleanup_phone_environment() {
    local phone_name=$1
    local display_num=$(get_phone_display "$phone_name")
    
    # Kill Xephyr instance
    pkill -f "Xephyr.*:$display_num"
    
    # Kill associated processes
    DISPLAY=":$display_num" pkill gnome-shell
    DISPLAY=":$display_num" pkill gnome-terminal
}
