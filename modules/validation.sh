#!/bin/bash

# Input validation and system check module
# Responsible for:
# - Resolution and framerate validation
# - Device existence and accessibility checks
# - System resource monitoring
# - Dependency verification
# - Parameter validation for all modules

# Verify resolution format (widthxheight)
validate_resolution() {
    local resolution=$1
    if [[ ! $resolution =~ ^[0-9]+x[0-9]+$ ]]; then
        log_error "Invalid resolution format: $resolution"
        return 1
    fi
}

# Check framerate is within acceptable range (1-120)
validate_framerate() {
    local framerate=$1
    if ! [[ $framerate =~ ^[0-9]+$ ]] || ((framerate < 1 || framerate > 120)); then
        log_error "Invalid framerate: $framerate"
        return 1
    fi
}

# Ensure video device exists and is accessible
validate_video_device() {
    local device=$1
    if [ ! -e "$device" ]; then
        log_error "Device not found: $device"
        return 1
    fi
    echo "$device"
}

# Validate device parameters and apply configurations
validate_device_parameters() {
    local device=$1
    local label=${2:-""}
    local format=${3:-""}

    if [ ! -e "$device" ]; then
        log_error "Device not found: $device"
        return 1
    fi

    if [ -n "$label" ] && ! v4l2-ctl -d "$device" --set-ctrl=name="$label" 2>/dev/null; then
        log_warn "Could not set device label: $label"
    fi

    if [ -n "$format" ] && ! v4l2loopback-ctl set-caps "$format" "$device" 2>/dev/null; then
        log_warn "Could not set device format: $format"
    fi

    return 0
}

# Check system memory and CPU load meet requirements
check_system_resources() {
    local min_memory=${1:-1000}
    local max_load=${2:-80}
    
    local mem_available=$(free -m | awk '/^Mem:/{print $7}')
    local cpu_load=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1)

    if ((mem_available < min_memory)); then
        log_error "Insufficient memory: ${mem_available}MB available"
        return 1
    fi

    if ((${cpu_load%.*} > max_load)); then
        log_error "System under heavy load: ${cpu_load}"
        return 1
    fi
}

# Verify all required system tools are installed
check_dependencies() {
    local deps=("ffmpeg" "v4l2-ctl" "v4l2loopback-ctl")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log_error "Required dependency '$dep' not found"
            return 1
        fi
    done
}

# Validate audio input device and settings
validate_audio_input() {
    local input=$1
    local rate=${2:-"$DEFAULT_AUDIO_RATE"}
    local channels=${3:-"$DEFAULT_AUDIO_CHANNELS"}

    # Check if pulseaudio is running
    if ! pulseaudio --check; then
        log_error "PulseAudio is not running"
        return 1
    fi

    # Verify audio input exists
    if ! pactl list sources | grep -q "$input"; then
        log_error "Audio input not found: $input"
        return 1
    fi

    return 0
}
