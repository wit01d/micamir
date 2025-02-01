# MICAMIR: Multimedia Interface Capture And Management In Real-time

A Linux-based system that creates virtual multimedia devices that fully emulate physical hardware. Applications interact with these virtual devices exactly as they would with real cameras and microphones, enabling seamless integration with any software that expects physical multimedia hardware.

## Features

- **Hardware Device Emulation**
  - Presents virtual devices as native hardware to applications
  - Complete v4l2 device interface implementation
  - Transparent hardware abstraction layer
  - Native device driver integration
- **Virtual Device Management**
  - Dynamic video device creation and configuration
  - Virtual microphone setup with PulseAudio integration
  - Multi-device synchronization
- **Video Capabilities**

  - Window/screen/region capture
  - Custom resolution and framerate control
  - Advanced video effects and filters
  - Multi-format streaming support

- **Audio Processing**

  - System audio capture
  - Audio quality enhancement
  - Real-time audio effects
  - Multi-source mixing

- **Android Integration**
  - Multiple emulator management
  - Camera and display virtualization
  - Automated environment setup

## System Requirements

- Linux-based operating system
- FFmpeg
- v4l2loopback
- PulseAudio
- X11 environment
- Optional: Android SDK for emulation features

## Installation

```bash
# Clone repository
git clone https://github.com/wit01d/micamir.git
cd micamir

# Install dependencies
./setup.sh install-required-packages

# Setup virtual devices
./setup.sh setup-camera
```

## Usage Examples

1. Create virtual camera:

```bash
./setup.sh setup-camera
```

2. Capture screen:

```bash
./setup.sh capture-screen 1920x1080 30
```

3. Stream video with audio:

```bash
./setup.sh stream-video-audio input.mp4
```

4. Launch Android emulators:

```bash
./setup.sh phones phone1 phone2
```

## Module Structure

```
modules/
├── android.sh    # Android emulator management
├── audio.sh      # Audio stream handling
├── cleanup.sh    # Resource cleanup
├── config.sh     # Configuration management
├── display.sh    # Display management
├── logging.sh    # Logging system
├── packages.sh   # Dependency management
├── validation.sh # Input validation
└── video.sh      # Video capture and streaming
```

## Configuration

The system uses a modular configuration system defined in `config.sh`. Key settings include:

- Video parameters (resolution, framerate, codec)
- Audio settings (rate, channels, format)
- Device mappings
- System paths
- Android emulator configurations

## Error Handling

The system implements comprehensive error handling:

- Input validation
- Resource verification
- Process monitoring
- Graceful cleanup
- Detailed logging

## The Journey of MICAMIR

In the ever-evolving landscape of multimedia applications, MICAMIR emerged as a solution for seamless virtual device integration. By perfectly emulating hardware interfaces, it creates virtual cameras and microphones that are indistinguishable from physical devices at the system level.

The virtual camera (video.sh) implements complete v4l2 device protocols, while the virtual microphone (audio.sh) provides native PulseAudio hardware device emulation. The validation.sh and packages.sh modules ensure proper system integration and compatibility across different applications.

The development path faced numerous challenges. The android.sh module, with its ambitious task of emulating reality on virtual emulators, encountered significant technical hurdles. Through persistent iteration, each component evolved - from display.sh's orchestrated window layouts to config.sh's delicate balance of parameters.

MICAMIR's genius lies in its ability to masquerade as actual hardware—passing off as a bona fide integrated camera and microphone. This ingenious design grants applications the illusion of interacting with real physical devices, streamlining integration and delivering unmatched performance in multimedia capture and streaming.

The project's architecture represents a convergence of disparate ideas into a resilient system that captures both multimedia and the spirit of technical innovation. This collection of interconnected modules, each with its own distinct purpose, exemplifies the power of creativity fused with technology.

Behind every command and line of code lies a story of innovation, challenges, and the transformative journey toward technical excellence.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT with Attribution License - see [LICENSE.md](LICENSE.md) for details. Any use of this software requires visible attribution to the MICAMIR Project.

## Acknowledgments

- FFmpeg project
- v4l2loopback developers
- PulseAudio team
- Android Open Source Project
