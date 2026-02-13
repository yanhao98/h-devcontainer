# Docker Desktop Integration Size Impact Analysis

## Summary

Based on package dependency analysis using `apt-get install -s` and estimations for base system differences between `debian:trixie-slim` and the sandbox environment (Ubuntu 24.04), integrating the `h-setup-desktop-lite` script into the Docker image will increase the image size by approximately **350MB - 400MB**.

## Breakdown

### 1. New Packages (~286 MB)
Packages explicitly listed in `h-setup-desktop-lite` and their direct dependencies (calculated on sandbox):
- **Fluxbox**: Minimal window manager (~3MB).
- **Nautilus**: File manager (~1.6MB + ~50MB deps like `libnautilus-extension`, `gnome-desktop`, `gvfs`).
- **Tilix**: Terminal emulator (~3.7MB + GTK/D deps).
- **TigerVNC**: VNC server (~3MB + X11 deps).
- **Fonts**: `fonts-noto-core` (~40MB), `fonts-wqy-microhei` (~5MB), `fonts-droid-fallback` (~7MB).
- **Python libraries**: `python3-numpy` (~23MB), `python3-minimal` (~5MB).

### 2. Base System Dependencies (~50-100 MB)
Dependencies that are pre-installed in the sandbox but missing in `debian:trixie-slim`:
- **GTK3/4 Stack**: Libraries like `libgtk-3-0`, `libgtk-4-1`, `libglib2.0-0` (~30MB).
- **X11 Client Libraries**: `libx11-6`, `libxcb1`, `libwayland-client0` (~10MB).
- **Mesa Drivers**: Likely excluded due to `--no-install-recommends` (saving ~40MB), but core GL dispatchers (`libgl1`) are required (~5MB).
- **Python Core**: Full Python standard library (~30MB) if not fully covered by minimal package.

### 3. Downloaded Assets (~20 MB)
- **noVNC**: Web VNC client (~5MB).
- **Cascadia Code Fonts**: Additional fonts downloaded by `install.sh` (~10MB).
- **Websockify**: (~1MB).

## Conclusion
The total estimated size increase is roughly **350MB - 400MB** on top of the base `debian:trixie-slim` image. Direct `docker build` verification was not possible due to environment limitations (`overlayfs` mount restrictions), but this estimate aligns with typical minimal desktop environment sizes.
