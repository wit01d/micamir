#!/bin/bash

# Main setup and orchestration script
# Provides:
# - Module loading and initialization
# - Command-line interface
# - Signal handling and error management
# - Resource validation
# - Feature execution routing
# - Help and version information

# Version information
readonly VERSION="1.0.0"
readonly SCRIPT_NAME=$(basename "$0")

# Import modules
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/modules/config.sh"
source "${SCRIPT_DIR}/modules/logging.sh"
source "${SCRIPT_DIR}/modules/validation.sh"
source "${SCRIPT_DIR}/modules/video.sh"
source "${SCRIPT_DIR}/modules/audio.sh"
source "${SCRIPT_DIR}/modules/android.sh"
source "${SCRIPT_DIR}/modules/display.sh"
source "${SCRIPT_DIR}/modules/cleanup.sh"
source "${SCRIPT_DIR}/modules/packages.sh"

# Signal handling
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
trap cleanup EXIT

error_handler() {
    local line_no=$1
    local command=$2
    local error_code=${3:-1}
    log_error "Error in line ${line_no}, command '${command}' exited with code ${error_code}"
    cleanup
    exit "${error_code}"
}
trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR

main() {
    # Add version and help options
    case "$1" in
        -v|--version)
            echo "$SCRIPT_NAME version $VERSION"
            exit 0
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
    esac

    check_dependencies || exit 1
    check_system_resources || exit 1

    case "$1" in
        "setup-camera") setup_virtual_camera "${@:2}" ;;
        "capture-window") capture_window "${@:2}" ;;
        "capture-screen") capture_screen "${@:2}" ;;
        "capture-area") capture_custom_area "${@:2}" ;;
        "nested-display") setup_nested_display "${@:2}" ;;
        "virtual-mic") create_virtual_mic ;;
        "stream-audio") stream_audio "${@:2}" ;;
        "stream-video") stream_video "${@:2}" ;;
        "android-emu") setup_android_emulator "${@:2}" ;;
        "phones") launch_multiple_phones "${@:2}" ;;
        "stream-transpose") stream_video_with_transpose "${@:2}" ;;
        "stream-codec") stream_video_with_codec "${@:2}" ;;
        "stream-audio-quality") stream_audio_with_quality "${@:2}" ;;
        "apply-audio-effects") apply_audio_effects "${@:2}" ;;
        "stream-image") stream_image "${@:2}" ;;
        "capture-desktop-advanced") capture_desktop_advanced "${@:2}" ;;
        "download-youtube") download_youtube "${@:2}" ;;
        "stream-video-audio-quality") stream_video_with_audio_quality "${@:2}" ;;
        "set-format") set_video_format "${@:2}" ;;
        "setup-compression") setup_audio_compression "${@:2}" ;;
        "stream-enhanced") stream_video_with_audio_enhanced "${@:2}" ;;
        "capture-custom") execute_safely capture_custom_window "${@:2}" ;;
        "stream-to-mic") execute_safely stream_video_to_mic "${@:2}" ;;
        "capture-desktop-monitor") execute_safely capture_desktop_with_audio_monitor "${@:2}" ;;
        "capture-nested") capture_nested_screen "${@:2}" ;;
        "stream-complex") stream_video_with_complex_audio "${@:2}" ;;
        "capture-layout") capture_windows_layout "${@:2}" ;;
        "stream-scale") stream_video_with_scaling "${@:2}" ;;
        "stream-correct") stream_video_with_correction "${@:2}" ;;
        "stream-overlay") stream_video_with_overlay "${@:2}" ;;
        "stream-filters") stream_video_with_filters "${@:2}" ;;
        "capture-region") capture_region "${@:2}" ;;
        "mix-audio") mix_audio_sources "${@:2}" ;;
        "stream-audio-loop") stream_audio_loop "${@:2}" ;;
        "copy-video") copy_raw_video "${@:2}" ;;
        "capture-desktop-audio") capture_desktop_with_audio "${@:2}" ;;
        *) show_usage ;;
    esac
}

show_usage() {
    echo "Usage: $SCRIPT_NAME [OPTIONS] COMMAND [ARGS...]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo
    echo "Commands:"
    echo "  setup-camera     - Setup virtual camera devices"
    echo "  capture-window   - Capture specific window"
    echo "  capture-screen   - Capture full screen"
    echo "  capture-area     - Capture specific screen area"
    echo "  nested-display   - Setup nested display"
    echo "  virtual-mic      - Create virtual microphone"
    echo "  stream-audio     - Stream audio to virtual mic"
    echo "  stream-video     - Stream video to virtual camera"
    echo "  android-emu      - Setup Android emulator"
    echo "  phones           - Launch multiple phone emulators"
    echo "  stream-transpose    - Stream video with transpose"
    echo "  stream-codec        - Stream video with specific codec"
    echo "  stream-audio-quality - Stream audio with quality settings"
    echo "  stream-video-audio-quality - Stream video with audio quality settings"
    echo "  apply-audio-effects - Apply audio enhancement effects"
    echo "  stream-image       - Stream static image to virtual camera"
    echo "  capture-desktop-advanced - Capture desktop with advanced options"
    echo "  download-youtube   - Download and convert YouTube video"
    echo "  set-format        - Set video format for device"
    echo "  setup-compression - Setup audio compression"
    echo "  stream-enhanced   - Stream video with enhanced audio"
    echo "  capture-custom     - Capture custom-sized window"
    echo "  stream-to-mic      - Stream video to virtual mic"
    echo "  capture-desktop-monitor - Capture desktop with audio monitoring"
    echo "  capture-nested    - Capture from nested display"
    echo "  stream-complex    - Stream video with complex audio settings"
    echo "  capture-layout    - Capture windows layout from file"
    echo "  stream-scale     - Stream video with custom scaling"
    echo "  stream-correct   - Stream video with color correction"
    echo "  stream-overlay    - Stream video with overlay image"
    echo "  stream-filters    - Stream video with custom filters"
    echo "  capture-region    - Capture region from coordinates file"
    echo "  mix-audio        - Mix two audio sources"
    echo "  stream-audio-loop - Stream audio with loop and fade"
    echo "  stream-nested    - Stream from nested screen"
    echo "  copy-video       - Copy raw video between devices"
    echo "  capture-desktop-audio - Capture desktop with synchronized audio"
    echo
    echo "For more information, visit: https://github.com/yourusername/yourrepo"
}

main "$@"
