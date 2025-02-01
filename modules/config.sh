#!/bin/bash

# Configuration management module
# Defines:
# - Default video/audio parameters
# - System paths and directories
# - Device mappings and configurations
# - Phone emulator settings
# - Display configurations
# - Configuration validation

# Default video configuration
readonly DEFAULT_RESOLUTION="1280x720"
readonly DEFAULT_FRAMERATE="30"
readonly DEFAULT_PIX_FMT="yuv420p"
readonly DEFAULT_VCODEC="rawvideo"

# Video compression settings
readonly DEFAULT_VIDEO_BITRATE="2M"
readonly DEFAULT_GOP_SIZE="24"
readonly DEFAULT_PRESET="fast"

# Default audio configuration
readonly DEFAULT_AUDIO_RATE="44100"
readonly DEFAULT_AUDIO_CHANNELS="2"
readonly DEFAULT_AUDIO_FORMAT="s16le"
readonly DEFAULT_AUDIO_BITRATE="32k"
readonly DEFAULT_AUDIO_CODEC="aac"

# System paths configuration
readonly DEFAULT_PIPE_DIR="/tmp"
readonly DEFAULT_MIC_PIPE="${DEFAULT_PIPE_DIR}/Microphone"
readonly DEFAULT_ANDROID_SDK_PATH="$HOME/Android/Sdk"
readonly LOG_FILE="/var/log/v4l2loopback.log"

# Virtual device mapping
readonly DEFAULT_OUTPUT_VIDEO="/dev/video0"
readonly PRIMARY_VIDEO="/dev/video0"
readonly SECONDARY_VIDEO="/dev/video1"
readonly PASSTHROUGH_VIDEO="/dev/video2"

# Phone emulator configurations
declare -A PHONE_CONFIGS
while IFS=':' read -r name camera display device; do
    PHONE_CONFIGS[$name]="${camera}:${display}:${device}"
done <<EOF
phone1:webcam1:2:video2
phone2:webcam1:3:video3
phone3:webcam1:4:video4
phone4:webcam1:5:video5
phone5:webcam1:6:video6
EOF

# Display configuration matrix
DISPLAY_CONFIGS=(
    "2:1280x720"
    "3:1280x720"
    "4:1280x720"
    "5:1280x720"
)

# Validate all configuration parameters
validate_config() {
    # Validate required directories exist
    for dir in "$DEFAULT_PIPE_DIR" "$DEFAULT_ANDROID_SDK_PATH"; do
        if [ ! -d "$dir" ]; then
            log_error "Required directory not found: $dir"
            return 1
        fi
    done

    # Validate log file directory is writable
    local log_dir=$(dirname "$LOG_FILE")
    if [ ! -w "$log_dir" ]; then
        log_error "Log directory not writable: $log_dir"
        return 1
    fi

    # Add phone config validation
    for phone in "${!PHONE_CONFIGS[@]}"; do
        local config="${PHONE_CONFIGS[$phone]}"
        if [[ ! "$config" =~ ^webcam[0-9]+:[0-9]+:video[0-9]+$ ]]; then
            log_error "Invalid phone configuration for $phone: $config"
            return 1
        fi
    done

    return 0
}

# Call validation when sourced
validate_config || {
    echo "Configuration validation failed"
    exit 1
}
