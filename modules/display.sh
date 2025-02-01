#!/bin/bash

# Display management module
# Handles:
# - Nested X server creation and management
# - Desktop capture with audio synchronization
# - Custom screen region capture
# - Multi-window layout management
# - Display configuration and setup

# Create nested X server with GNOME Shell for isolated display
setup_nested_display() {
    local display_num=${1:-2}
    local resolution=${2:-"$DEFAULT_RESOLUTION"}
    local video_device=${3:-"$OUTPUT_VIDEO"}

    video_device=$(validate_video_device "$video_device") || return 1

    execute_safely Xephyr -screen "$resolution" -s off -reset -terminate ":$display_num"
    sleep 1

    DISPLAY=":$display_num" dbus-run-session gnome-shell &
    DISPLAY=":$display_num" gnome-terminal --command "xrandr --size $resolution" &

    capture_screen "$DEFAULT_FRAMERATE" "$video_device" ":$display_num"
}

# Capture desktop with audio stream to virtual devices
capture_desktop_with_audio() {
    local video_device=${1:-"$OUTPUT_VIDEO"}
    local display_source=${2:-"$DISPLAY"}
    local resolution=${3:-"$DEFAULT_RESOLUTION"}
    local framerate=${4:-"$DEFAULT_FRAMERATE"}

    video_device=$(validate_video_device "$video_device") || return 1

    execute_safely ffmpeg -f x11grab -video_size "$resolution" -framerate "$framerate" \
        -i "$display_source" -f alsa -i default \
        -vf scale="$resolution" -c:v h264_nvenc \
        -f v4l2 "$video_device" \
        -f "$DEFAULT_AUDIO_FORMAT" - > "$DEFAULT_MIC_PIPE"
}

# Capture specific screen region with custom dimensions
capture_custom_area() {
    local x=${1:-"0"}
    local y=${2:-"0"}
    local width=${3:-"1280"}
    local height=${4:-"720"}
    local device=${5:-"$OUTPUT_VIDEO"}

    device=$(validate_video_device "$device") || return 1

    execute_safely ffmpeg -f x11grab -r "$DEFAULT_FRAMERATE" \
        -s "${width}x${height}" -i ":0.0+$x,$y" \
        -vcodec rawvideo -pix_fmt yuv420p -threads 0 \
        -f v4l2 "$device"
}

# Capture multiple windows based on layout configuration file
capture_windows_layout() {
    local layout_file=$1
    local device=${2:-"$OUTPUT_VIDEO"}
    local display=${3:-":0.0"}

    device=$(validate_video_device "$device") || return 1

    while IFS=':' read -r window_id geometry; do
        IFS='x+' read -r width height x y <<< "$geometry"
        execute_safely ffmpeg -f x11grab -r 15 -s "${width}x${height}" \
            -i "$display+$x,$y" -vcodec rawvideo -pix_fmt yuv420p \
            -threads 0 -f v4l2 "$device"
    done < "$layout_file"
}
