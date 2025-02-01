#!/bin/bash

# Installation and dependency management module
# Handles system package installation and validation

# Required packages for core functionality
readonly REQUIRED_PACKAGES=(
    ffmpeg
    v4l2loopback-dkms
    v4l2loopback-utils
    v4l-utils
    pulseaudio
    alsa-utils
    xdpyinfo
    youtube-dl
    build-essential # compiling tools if needed
    linux-headers-$(uname -r) # building kernel modules
    x11-utils # X11 tools like xdpyinfo
    x11-xserver-utils # X server utilities
    pkg-config # building from source if needed
)

# Optional packages for enhanced functionality
readonly OPTIONAL_PACKAGES=(
    adb
    fastboot
    qemu-kvm
    nvidia-cuda-toolkit
    pavucontrol # PulseAudio volume control
    obs-studio # advanced video capture
)

# Check if package is installed
is_package_installed() {
    dpkg -l "$1" &>/dev/null
}

# Install a single package
install_package() {
    local package=$1
    if ! is_package_installed "$package"; then
        log_info "Installing package: $package"
        if ! sudo apt-get install -y "$package"; then
            log_error "Failed to install package: $package"
            return 1
        fi
    fi
    return 0
}

# Install all required packages
install_required_packages() {
    log_info "Updating package lists..."
    if ! sudo apt-get update; then
        log_error "Failed to update package lists"
        return 1
    fi

    log_info "Installing required packages..."
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! install_package "$package"; then
            return 1
        fi
    done

    return 0
}

# Install optional packages
install_optional_packages() {
    log_info "Installing optional packages..."
    for package in "${OPTIONAL_PACKAGES[@]}"; do
        install_package "$package" || log_warning "Optional package installation failed: $package"
    done
}

# Check if required packages are installed
check_dependencies() {
    local missing_packages=()

    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! is_package_installed("$package"); then
            missing_packages+=("$package")
        fi
    done

    if [ ${#missing_packages[@]} -gt 0 ]; then
        log_warning "Missing required packages: ${missing_packages[*]}"
        read -p "Would you like to install missing packages? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_required_packages
            return $?
        else
            return 1
        fi
    fi

    return 0
}

# Setup kernel modules
setup_kernel_modules() {
    log_info "Setting up kernel modules..."
    
    # Add v4l2loopback to /etc/modules if not already present
    if ! grep -q "v4l2loopback" /etc/modules; then
        echo "v4l2loopback" | sudo tee -a /etc/modules
    fi

    # Load module if not already loaded
    if ! lsmod | grep -q "v4l2loopback"; then
        sudo modprobe v4l2loopback
    fi
}

# Configure audio system
setup_audio() {
    log_info "Configuring audio system..."
    
    # Restart pulseaudio if needed
    pulseaudio --check || pulseaudio --start

    # Set default audio configuration
    pacmd set-default-source alsa_input.pci-0000_00_1f.3.analog-stereo
}
