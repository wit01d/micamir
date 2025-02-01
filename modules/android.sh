#!/bin/bash

# Android emulator management module
# Provides functionality for:
# - Setting up and configuring Android emulators
# - Managing multiple emulator instances
# - Handling camera and display configurations
# - Environment setup and cleanup
# - Device mapping and path resolution

# Set up Android emulator with custom camera and display configuration
setup_android_emulator() {
    local avd_name=${1:-"phone1"}
    
    # Add validation
    validate_phone_config "$avd_name" || return 1

    local cam_device=$(get_phone_camera "$avd_name")
    local display_num=$(get_phone_display "$avd_name")
    local video_device=$(get_phone_device "$avd_name")

    [ -d "$HOME/.android/avd/${avd_name}.avd/" ] || { log_error "AVD not found: $avd_name"; return 1; }
    [ -d "$DEFAULT_ANDROID_SDK_PATH/emulator" ] || { log_error "Android SDK emulator not found"; return 1; }

    # Clean up existing instances
    cleanup_phone_environment "$avd_name"

    # Setup environment
    setup_phone_environment "$avd_name" || return 1

    cd "$DEFAULT_ANDROID_SDK_PATH/emulator" || return 1
    DISPLAY=":$display_num" execute_safely ./emulator -avd "$avd_name" \
        -camera-back "$video_device" \
        -camera-front "$video_device" \
        -gpu on \
        -no-snapshot-load \
        -no-boot-anim \
        -allow-host-audio \
        -writable-system
}

# Validate phone configuration including AVD existence and format
validate_phone_config() {
    local avd_name=$1
    
    # Check AVD exists
    local avd_path="$HOME/.android/avd/${avd_name}.avd"
    if [ ! -d "$avd_path" ]; then
        log_error "AVD not found: $avd_name"
        return 1
    }

    # Check config exists
    if [ -z "${PHONE_CONFIGS[$avd_name]}" ]; then
        log_error "No configuration found for phone: $avd_name"
        return 1
    }

    # Validate phone configuration format
    local config="${PHONE_CONFIGS[$avd_name]}"
    if [[ ! "$config" =~ ^webcam[0-9]+:[0-9]+:video[0-9]+$ ]]; then
        log_error "Invalid configuration format for phone: $avd_name"
        return 1
    }

    return 0
}

# Extract camera configuration from phone settings
get_phone_camera() {
    local phone_name=$1
    echo "${PHONE_CONFIGS[$phone_name]%%:*}"
}

# Get display number for specific phone configuration
get_phone_display() {
    local phone_name=$1
    local config="${PHONE_CONFIGS[$phone_name]}"
    echo "${config#*:}" | cut -d: -f1
}

# Extract video device path for phone configuration
get_phone_device() {
    local phone_name=$1
    echo "${PHONE_CONFIGS[$phone_name]##*:}"
}

# Initialize X11 environment and video capture for phone emulator
setup_phone_environment() {
    local phone_name=$1
    local display_num=$(get_phone_display "$phone_name") || return 1
    local video_device=$(get_phone_device "$phone_name") || return 1

    # Ensure previous instances are cleaned up
    cleanup_phone_environment "$phone_name"

    # Setup display
    Xephyr -screen "$DEFAULT_RESOLUTION" -s off -reset -terminate ":$display_num" 2>/dev/null &
    sleep 2  # Increased sleep time for better stability

    # Configure display environment
    DISPLAY=":$display_num" dbus-run-session gnome-shell &
    DISPLAY=":$display_num" gnome-terminal --command "xrandr --size $DEFAULT_RESOLUTION" &

    # Setup video capture with dynamic device
    DISPLAY=":$display_num" execute_safely ffmpeg -f x11grab -r 15 -s "$DEFAULT_RESOLUTION" \
        -i ":$display_num.0+0,0" -vcodec rawvideo -pix_fmt yuv420p \
        -threads 0 -f v4l2 "$video_device" &
}

# Launch multiple Android emulator instances in parallel
launch_multiple_phones() {
    local phones=("$@")
    if [ ${#phones[@]} -eq 0 ]; then
        phones=("phone1")
    fi

    for phone in "${phones[@]}"; do
        setup_android_emulator "$phone" &
    done
    wait
}

# Map display numbers to corresponding video devices
DEVICE_MAPPING=(
    "2:video2"
    "3:video3"
    "4:video4"
    "5:video5"
    "6:video6"
)

# Convert display number to device path using mapping table
get_device_path() {
    local display_num=$1
    for mapping in "${DEVICE_MAPPING[@]}"; do
        IFS=':' read -r disp dev <<<"$mapping"
        if [ "$disp" = "$display_num" ]; then
            echo "/dev/$dev"
            return 0
        fi
    done
    echo "/dev/video$display_num" # Fallback
}
