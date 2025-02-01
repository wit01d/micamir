#!/bin/bash

# Audio module providing comprehensive audio stream handling and manipulation
# Features:
# - Virtual microphone creation and management
# - Audio streaming with quality control
# - Audio effects and filters
# - System audio capture
# - Mixed audio handling
# - Synchronized video-audio streaming

# Create and configure a virtual microphone using PulseAudio pipe source
create_virtual_mic() {
    local pipe_file="$DEFAULT_MIC_PIPE"

    [ -p "$pipe_file" ] || mkfifo "$pipe_file"

    execute_safely pactl load-module module-pipe-source \
        source_name=VirtualMic \
        file="$pipe_file" \
        format="$DEFAULT_AUDIO_FORMAT" \
        rate="$DEFAULT_AUDIO_RATE" \
        channels="$DEFAULT_AUDIO_CHANNELS"

    execute_safely pactl set-default-source VirtualMic
}

# Stream audio file continuously to virtual microphone
stream_audio() {
    local input_file=$1
    [ -f "$input_file" ] || { log_error "Input file not found: $input_file"; return 1; }

    execute_safely ffmpeg -stream_loop -1 -re -i "$input_file" \
        -f "$DEFAULT_AUDIO_FORMAT" -ar "$DEFAULT_AUDIO_RATE" -ac "$DEFAULT_AUDIO_CHANNELS" \
        - > "$DEFAULT_MIC_PIPE"
}

# Stream audio with configurable quality settings (bitrate and codec)
stream_audio_with_quality() {
    local input_file=$1
    local bitrate=${2:-"$DEFAULT_AUDIO_BITRATE"}
    local codec=${3:-"$DEFAULT_AUDIO_CODEC"}

    [ -f "$input_file" ] || { log_error "Input file not found: $input_file"; return 1; }

    execute_safely ffmpeg -stream_loop -1 -re -i "$input_file" \
        -c:a "$codec" -b:a "$bitrate" \
        -f "$DEFAULT_AUDIO_FORMAT" -ar "$DEFAULT_AUDIO_RATE" -ac "$DEFAULT_AUDIO_CHANNELS" \
        - > "$DEFAULT_MIC_PIPE"
}

# Apply audio enhancement filters (volume, EQ, compression)
apply_audio_effects() {
    local input_file=$1
    local output_file=${2:-"$DEFAULT_MIC_PIPE"}
    
    execute_safely ffmpeg -i "$input_file" \
        -af "volume=1.5,highpass=f=200,lowpass=f=3000,compand=.3|.3:1|1:-90/-60|-60/-40|-40/-30|-20/-20:6:0:-90:0.2" \
        -f "$DEFAULT_AUDIO_FORMAT" -ar "$DEFAULT_AUDIO_RATE" -ac "$DEFAULT_AUDIO_CHANNELS" \
        - > "$output_file"
}

# Capture system audio output using ALSA interface
capture_system_audio() {
    local output_file=${1:-"$DEFAULT_MIC_PIPE"}

    execute_safely ffmpeg -f alsa -i alsa_output.pci-0000_00_1f.3.analog-stereo.monitor \
        -f "$DEFAULT_AUDIO_FORMAT" -ar "$DEFAULT_AUDIO_RATE" -ac "$DEFAULT_AUDIO_CHANNELS" \
        - > "$output_file"
}

# Capture audio using PulseAudio interface
capture_pulse_audio() {
    local output_file=${1:-"$DEFAULT_MIC_PIPE"}

    execute_safely ffmpeg -f pulse -i default \
        -f "$DEFAULT_AUDIO_FORMAT" -ar "$DEFAULT_AUDIO_RATE" -ac "$DEFAULT_AUDIO_CHANNELS" \
        - > "$output_file"
}

# Stream video file with synchronized audio output
stream_video_with_audio() {
    local input_file=$1
    local video_device=${2:-"$OUTPUT_VIDEO"}

    [ -f "$input_file" ] || { log_error "Input file not found: $input_file"; return 1; }
    video_device=$(validate_video_device "$video_device") || return 1

    execute_safely ffmpeg -stream_loop -1 -re -i "$input_file" \
        -f v4l2 -vcodec rawvideo -pix_fmt yuv420p "$video_device" \
        -f "$DEFAULT_AUDIO_FORMAT" -ar "$DEFAULT_AUDIO_RATE" -ac "$DEFAULT_AUDIO_CHANNELS" \
        - > "$DEFAULT_MIC_PIPE"
}

# Stream video with configurable audio/video quality settings
stream_video_with_audio_quality() {
    local input_file=$1
    local video_device=${2:-"$OUTPUT_VIDEO"}
    local bitrate=${3:-"$DEFAULT_AUDIO_BITRATE"}
    local video_bitrate=${4:-"$DEFAULT_VIDEO_BITRATE"}

    [ -f "$input_file" ] || { log_error "Input file not found: $input_file"; return 1; }
    video_device=$(validate_video_device "$video_device") || return 1

    execute_safely ffmpeg -stream_loop -1 -re -i "$input_file" \
        -c:v h264_nvenc -b:v "$video_bitrate" \
        -f v4l2 -pix_fmt yuv420p "$video_device" \
        -c:a "$DEFAULT_AUDIO_CODEC" -b:a "$bitrate" \
        -f "$DEFAULT_AUDIO_FORMAT" -ar "$DEFAULT_AUDIO_RATE" -ac "$DEFAULT_AUDIO_CHANNELS" \
        - > "$DEFAULT_MIC_PIPE"
}

# Apply dynamic range compression to audio input
setup_audio_compression() {
    local input=$1
    local threshold=${2:-"0.089"}
    local ratio=${3:-"9"}
    local attack=${4:-"200"}
    local release=${5:-"1000"}

    execute_safely ffmpeg -i "$input" \
        -af "acompressor=threshold=$threshold:ratio=$ratio:attack=$attack:release=$release" \
        -f "$DEFAULT_AUDIO_FORMAT" -ar "$DEFAULT_AUDIO_RATE" -ac "$DEFAULT_AUDIO_CHANNELS" \
        - > "$DEFAULT_MIC_PIPE"
}

# Stream video with enhanced audio and video encoding options
stream_video_with_audio_enhanced() {
    local input_file=$1
    local video_device=${2:-"$OUTPUT_VIDEO"}
    local video_bitrate=${3:-"$DEFAULT_VIDEO_BITRATE"}
    local audio_bitrate=${4:-"$DEFAULT_AUDIO_BITRATE"}

    video_device=$(validate_video_device "$video_device") || return 1

    execute_safely ffmpeg -stream_loop -1 -re -i "$input_file" \
        -c:v h264_nvenc -b:v "$video_bitrate" -preset "$DEFAULT_PRESET" \
        -f v4l2 "$video_device" \
        -c:a "$DEFAULT_AUDIO_CODEC" -b:a "$audio_bitrate" \
        -f "$DEFAULT_AUDIO_FORMAT" - > "$DEFAULT_MIC_PIPE"
}

# Capture desktop video with system audio monitoring
capture_desktop_with_audio_monitor() {
    VIDEO_DEVICE=${1:-$OUTPUT_VIDEO}
    VIDEO_DEVICE=$(validate_video_device "$VIDEO_DEVICE") || return 1

    execute_safely ffmpeg -f x11grab -s 1280x720 -i "$DISPLAY" \
        -f v4l2 "$VIDEO_DEVICE" \
        -re -i alsa alsa_output.pci-0000_00_1f.3.analog-stereo.monitor \
        -f s16le - >/tmp/Microphone
}

# Mix two audio sources into single output stream
mix_audio_sources() {
    local input1=$1
    local input2=$2
    local output=${3:-"$DEFAULT_MIC_PIPE"}

    execute_safely ffmpeg -i "$input1" -i "$input2" \
        -filter_complex "amix=inputs=2:duration=first:dropout_transition=2" \
        -f "$DEFAULT_AUDIO_FORMAT" -ar "$DEFAULT_AUDIO_RATE" -ac "$DEFAULT_AUDIO_CHANNELS" \
        - > "$output"
}

# Stream audio with configurable loop duration and fade effects
stream_audio_loop() {
    # Input file validation and setup
    local input_file=$1
    local duration=${2:-"0"}
    local fade=${3:-"0"}

    [ -f "$input_file" ] || { log_error "Input file not found: $input_file"; return 1; }

    # Configure fade effects if enabled
    local fade_filter=""
    [ "$fade" != "0" ] && fade_filter=",afade=t=in:st=0:d=$fade,afade=t=out:st=$((duration-fade)):d=$fade"

    # Stream audio with loop and fade effects
    execute_safely ffmpeg -stream_loop -1 -re -i "$input_file" \
        -af "aloop=loop=-1:size=$duration$fade_filter" \
        -f "$DEFAULT_AUDIO_FORMAT" -ar "$DEFAULT_AUDIO_RATE" -ac "$DEFAULT_AUDIO_CHANNELS" \
        - > "$DEFAULT_MIC_PIPE"
}
