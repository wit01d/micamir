#!/bin/bash

# Video handling and processing module
# Provides comprehensive video capture, streaming, and manipulation functionality:
# - Virtual camera device management
# - Multi-source video capture (window, screen, area)
# - Video streaming with various encodings and filters
# - Process health monitoring and error handling
# - Advanced video effects and transformations

# Create v4l2loopback devices with specific configurations
setup_virtual_camera() {
    local devices=${1:-2}
    local label=${2:-"VirtualCam"}
    local setup_mic=${3:-false}

    check_system_resources || return 1

    log_info "Setting up virtual camera: $label with $devices devices"
    if ! execute_safely sudo modprobe v4l2loopback card_label="$label" exclusive_caps=1 devices="$devices"; then
        return 1
    fi

    OUTPUT_VIDEO=$(get_next_video_device)
    
    if [ "$setup_mic" = true ]; then
        sudo modprobe v4l2loopback card_label="Microphone" exclusive_caps=1 devices=1
    fi

    v4l2-ctl --list-devices
}

# Capture specific window with resolution and framerate control
capture_window() {
    local resolution=${1:-"$DEFAULT_RESOLUTION"}
    local framerate=${2:-"$DEFAULT_FRAMERATE"}
    local device=${3:-"$OUTPUT_VIDEO"}
    local display=${4:-":0.0"}

    validate_resolution "$resolution" || return 1
    validate_framerate "$framerate" || return 1
    device=$(validate_video_device "$device") || return 1

    execute_safely ffmpeg -f x11grab -r "$framerate" -s "$resolution" -i "$display"+0,0 \
        -vcodec rawvideo -pix_fmt yuv420p -threads 0 \
        -f v4l2 "$device"
}

# Capture full screen with automatic resolution detection
capture_screen() {
    local framerate=${1:-"$DEFAULT_FRAMERATE"}
    local device=${2:-"$OUTPUT_VIDEO"}
    local display=${3:-":0.0"}

    validate_framerate "$framerate" || return 1
    device=$(validate_video_device "$device") || return 1

    local resolution=$(xdpyinfo | grep dimensions | awk '{print $2}')
    execute_safely ffmpeg -f x11grab -r "$framerate" -s "$resolution" \
        -i "$display" -vcodec rawvideo -pix_fmt yuv420p -threads 0 \
        -f v4l2 "$device"
}

# Monitor video process health and handle failures gracefully
# Returns 0 if process is healthy, 1 otherwise
check_video_process() {
    local pid=$1
    local timeout=${2:-5}
    local count=0

    while ((count < timeout)); do
        if ! kill -0 "$pid" 2>/dev/null; then
            log_error "Video process failed to start"
            return 1
        fi
        if grep -q "^Error" "/proc/$pid/fd/2" 2>/dev/null; then
            log_error "Video process encountered an error"
            return 1
        fi
        sleep 1
        ((count++))
    done
    return 0
}

# Stream video file to virtual camera with loop control
stream_video() {
    local input_file=$1
    local output=${2:-"$OUTPUT_VIDEO"}
    local loop=${3:-"-1"}

    [ -f "$input_file" ] || { log_error "Input file not found: $input_file"; return 1; }
    output=$(validate_video_device "$output") || return 1

    # Start process in background for monitoring
    ffmpeg -stream_loop "$loop" -re -i "$input_file" \
        -f v4l2 -vcodec rawvideo -pix_fmt yuv420p \
        "$output" &
    local pid=$!

    # Check process health
    check_video_process "$pid" || {
        kill "$pid" 2>/dev/null
        return 1
    }
}

# Apply rotation/flip transformations to video stream
stream_video_with_transpose() {
    local input_file=$1
    local output=${2:-"$OUTPUT_VIDEO"}
    local transpose=${3:-"4"}

    [ -f "$input_file" ] || { log_error "Input file not found: $input_file"; return 1; }
    output=$(validate_video_device "$output") || return 1

    execute_safely ffmpeg -stream_loop -1 -re -i "$input_file" \
        -vf "transpose=$transpose" \
        -f v4l2 -vcodec rawvideo -pix_fmt yuv420p \
        "$output"
}

# Stream video with custom codec and quality settings
stream_video_with_codec() {
    local input_file=$1
    local output=${2:-"$OUTPUT_VIDEO"}
    local codec=${3:-"$DEFAULT_VCODEC"}
    local bitrate=${4:-"$DEFAULT_VIDEO_BITRATE"}

    [ -f "$input_file" ] || { log_error "Input file not found: $input_file"; return 1; }
    output=$(validate_video_device "$output") || return 1

    execute_safely ffmpeg -stream_loop -1 -re -i "$input_file" \
        -c:v "$codec" -b:v "$bitrate" \
        -f v4l2 -pix_fmt yuv420p \
        "$output"
}

# Stream video with synchronized audio handling
stream_video_with_complex_audio() {
    local input_file=$1
    local video_device=${2:-"$OUTPUT_VIDEO"}
    local audio_bitrate=${3:-"$DEFAULT_AUDIO_BITRATE"}
    local audio_rate=${4:-"$DEFAULT_AUDIO_RATE"}

    video_device=$(validate_video_device "$video_device") || return 1

    execute_safely ffmpeg -stream_loop 1 -re -i "$input_file" \
        -f v4l2 -vcodec "$DEFAULT_VCODEC" -pix_fmt "$DEFAULT_PIX_FMT" "$video_device" \
        -i "$input_file" -f alsa -acodec "$DEFAULT_AUDIO_CODEC" \
        -ac "$DEFAULT_AUDIO_CHANNELS" -ab "$audio_bitrate" -ar "$audio_rate" \
        -preset "$DEFAULT_PRESET" -g "$DEFAULT_GOP_SIZE"
}

# Find next available video device number on system
# Returns: Path to next available video device
get_next_video_device() {
    for i in {0..9}; do
        if [ ! -e "/dev/video$i" ]; then
            echo "/dev/video$i"
            log_info "Found available device: /dev/video$i"
            return 0
        fi
    done
    log_error "No available video devices found"
    return 1
}

# Mirror video output between devices
copy_device_output() {
    local input=${1:-"$PRIMARY_VIDEO"}
    local output=${2:-"$PASSTHROUGH_VIDEO"}

    input=$(validate_video_device "$input") || return 1
    output=$(validate_video_device "$output") || return 1

    execute_safely ffmpeg -i "$input" -vcodec rawvideo -pix_fmt yuv420p \
        -threads 0 -f v4l2 "$output"
}

# Stream static image as video source
stream_image() {
    local image_file=$1
    local output=${2:-"$OUTPUT_VIDEO"}

    [ -f "$image_file" ] || { log_error "Image file not found: $image_file"; return 1; }
    output=$(validate_video_device "$output") || return 1

    execute_safely ffmpeg -loop 1 -re -i "$image_file" \
        -f v4l2 -vcodec rawvideo -pix_fmt yuv420p \
        "$output"
}

# Advanced desktop capture with positioning
capture_desktop_advanced() {
    local resolution=${1:-"1030x1190"}
    local framerate=${2:-"15"}
    local offset=${3:-"0,0"}
    local output_device=${4:-"$OUTPUT_VIDEO"}

    validate_resolution "$resolution" || return 1
    validate_framerate "$framerate" || return 1
    output_device=$(validate_video_device "$output_device") || return 1

    execute_safely ffmpeg -f x11grab -r "$framerate" -s "$resolution" \
        -i ":0.0+$offset" -vcodec rawvideo -pix_fmt yuv420p \
        -threads 0 -f v4l2 "$output_device"
}

# Desktop capture with audio monitoring capability
capture_desktop_with_audio_monitor() {
    local video_device=${1:-"$OUTPUT_VIDEO"}
    video_device=$(validate_video_device "$video_device") || return 1

    execute_safely ffmpeg -f x11grab -s 1280x720 -i "$DISPLAY" \
        -f v4l2 "$video_device" \
        -re -i alsa alsa_output.pci-0000_00_1f.3.analog-stereo.monitor \
        -f s16le - > "$DEFAULT_MIC_PIPE"
}

# Download and process YouTube videos
download_youtube() {
    local url=$1
    local output=${2:-"downloaded_video.mp4"}

    execute_safely youtube-dl -f '136[ext=mp4]+140[ext=m4a]/136+140' \
        --merge-output-format mp4 \
        -o "$output" \
        "$url"
}

# Execute command with timeout protection
execute_with_timeout() {
    local timeout=${1:-30}
    local cmd="${@:2}"
    
    timeout "$timeout" $cmd || {
        log_error "Command timed out after ${timeout}s: $cmd"
        return 1
    }
}

# Capture specific screen area with coordinates
capture_area() {
    local x=${1:-"0"}
    local y=${2:-"0"}
    local width=${3:-"1280"}
    local height=${4:-"720"}
    local device=${5:-"$OUTPUT_VIDEO"}

    device=$(validate_video_device "$device") || return 1
    validate_resolution "${width}x${height}" || return 1

    execute_safely ffmpeg -f x11grab -r "$DEFAULT_FRAMERATE" -s "${width}x${height}" \
        -i ":0.0+$x,$y" -vcodec rawvideo -pix_fmt yuv420p -threads 0 \
        -f v4l2 "$device"
}

# Configure video format for virtual device
set_video_format() {
    local device=$1
    local format=${2:-"RGB24"}
    local resolution=${3:-"$DEFAULT_RESOLUTION"}

    device=$(validate_video_device "$device") || return 1
    
    execute_safely v4l2loopback-ctl set-caps \
        "video/x-raw,format=$format,width=${resolution%x*},height=${resolution#*x}" \
        "$device"
}

# Capture custom window with specific dimensions
capture_custom_window() {
    local width=${1:-"530"}
    local height=${2:-"1190"}
    local device=${3:-"$OUTPUT_VIDEO"}
    local display=${4:-":0.0"}

    device=$(validate_video_device "$device") || return 1

    execute_safely ffmpeg -f x11grab -r 15 -s "${width}x${height}" \
        -i "$display" -vcodec rawvideo -pix_fmt yuv420p \
        -threads 0 -f v4l2 "$device"
}

# Stream video to virtual microphone device
stream_video_to_mic() {
    local video_file=$1
    local video_device=${2:-"$OUTPUT_VIDEO"}
    local mic_file=${3:-"/tmp/Microphone"}

    video_device=$(validate_video_device "$video_device") || return 1

    execute_safely ffmpeg -stream_loop -1 -re -i "$video_file" \
        -f v4l2 -vcodec rawvideo -pix_fmt yuv420p "$video_device" \
        -f s16le -ar 44100 -ac 2 - >"$mic_file"
}

# Capture nested screen with specific display number
capture_nested_screen() {
    local display_num=${1:-"2"}
    local resolution=${2:-"$DEFAULT_RESOLUTION"}
    local device=${3:-"$OUTPUT_VIDEO"}

    device=$(validate_video_device "$device") || return 1

    execute_safely ffmpeg -f x11grab -r 15 -s "$resolution" \
        -i ":$display_num.0+0,0" -vcodec rawvideo -pix_fmt yuv420p \
        -threads 0 -f v4l2 "$device"
}

# Stream video with scaling and optional original size
stream_video_with_scaling() {
    local input_file=$1
    local output=${2:-"$OUTPUT_VIDEO"}
    local scale=${3:-"1280:720"}
    local force_original=${4:-false}

    [ -f "$input_file" ] || { log_error "Input file not found: $input_file"; return 1; }
    output=$(validate_video_device "$output") || return 1

    local scale_filter="-vf scale=$scale"
    [ "$force_original" = true ] && scale_filter=""

    execute_safely ffmpeg -stream_loop -1 -re -i "$input_file" \
        $scale_filter \
        -f v4l2 -vcodec rawvideo -pix_fmt yuv420p \
        "$output"
}

# Stream video with brightness, contrast, and saturation correction
stream_video_with_correction() {
    local input_file=$1
    local output=${2:-"$OUTPUT_VIDEO"}
    local brightness=${3:-"0"}
    local contrast=${4:-"1"}
    local saturation=${5:-"1"}

    [ -f "$input_file" ] || { log_error "Input file not found: $input_file"; return 1; }
    output=$(validate_video_device "$output") || return 1

    execute_safely ffmpeg -stream_loop -1 -re -i "$input_file" \
        -vf "eq=brightness=$brightness:contrast=$contrast:saturation=$saturation" \
        -f v4l2 -vcodec rawvideo -pix_fmt yuv420p \
        "$output"
}

# Stream video with overlay image
stream_video_with_overlay() {
    local input_file=$1
    local overlay_file=$2
    local output=${3:-"$OUTPUT_VIDEO"}
    local overlay_position=${4:-"10:10"}

    [ -f "$input_file" ] || { log_error "Input file not found: $input_file"; return 1; }
    [ -f "$overlay_file" ] || { log_error "Overlay file not found: $overlay_file"; return 1; }
    output=$(validate_video_device "$output") || return 1

    execute_safely ffmpeg -stream_loop -1 -re -i "$input_file" \
        -i "$overlay_file" \
        -filter_complex "overlay=$overlay_position" \
        -f v4l2 -vcodec rawvideo -pix_fmt yuv420p \
        "$output"
}

# Copy raw video between devices
copy_raw_video() {
    local input=${1:-"/dev/video2"}
    local output=${2:-"/dev/video4"}

    input=$(validate_video_device "$input") || return 1
    output=$(validate_video_device "$output") || return 1

    execute_safely ffmpeg -f v4l2 -i "$input" -vcodec rawvideo -pix_fmt yuv420p \
        -threads 0 -f v4l2 "$output"
}

# Capture desktop with audio input
capture_desktop_with_audio() {
    local video_device=${1:-"$OUTPUT_VIDEO"}
    local display_source=${2:-"$DISPLAY"}
    local resolution=${3:-"$DEFAULT_RESOLUTION"}
    local framerate=${4:-"$DEFAULT_FRAMERATE"}

    video_device=$(validate_video_device "$video_device") || return 1
    validate_resolution "$resolution" || return 1
    validate_framerate "$framerate" || return 1

    execute_safely ffmpeg -f x11grab -video_size "$resolution" -framerate "$framerate" \
        -i "$display_source" -f alsa -i default \
        -af acompressor=threshold=0.089:ratio=9:attack=200:release=1000 \
        -vf scale="$resolution" -c:v h264_nvenc -g "$DEFAULT_GOP_SIZE" -b:v "$DEFAULT_VIDEO_BITRATE" \
        -preset "$DEFAULT_PRESET" -c:a "$DEFAULT_AUDIO_CODEC" -pix_fmt "$DEFAULT_PIX_FMT" \
        -f v4l2 "$video_device" \
        -f "$DEFAULT_AUDIO_FORMAT" - > "$DEFAULT_MIC_PIPE"
}

# Stream video with custom filters
stream_video_with_filters() {
    local input_file=$1
    local output=${2:-"$OUTPUT_VIDEO"}
    local filters=${3:-""}

    [ -f "$input_file" ] || { log_error "Input file not found: $input_file"; return 1; }
    output=$(validate_video_device "$output") || return 1

    execute_safely ffmpeg -stream_loop -1 -re -i "$input_file" \
        -vf "$filters" \
        -f v4l2 -vcodec rawvideo -pix_fmt yuv420p \
        "$output"
}

# Capture specific region of screen
capture_region() {
    local region_file=$1
    local device=${2:-"$OUTPUT_VIDEO"}
    
    device=$(validate_video_device "$device") || return 1

    # Format: x,y,width,height
    IFS=',' read -r x y width height < "$region_file"
    execute_safely ffmpeg -f x11grab -r "$DEFAULT_FRAMERATE" \
        -s "${width}x${height}" -i ":0.0+$x,$y" \
        -vcodec rawvideo -pix_fmt yuv420p -threads 0 \
        -f v4l2 "$device"
}
