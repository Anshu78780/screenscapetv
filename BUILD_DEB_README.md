# Debian Package Build Script

## Overview

This script (`build-deb.sh`) automates the process of building a `.deb` package for ScreenScapeTV on Linux distributions.

## Features

- ✅ Builds Flutter Linux application in release mode
- ✅ Converts and prepares application icon from JPG to PNG
- ✅ Creates proper Debian package structure
- ✅ Generates control file with dependencies
- ✅ Creates post-install and post-remove scripts
- ✅ Sets correct permissions
- ✅ Builds and verifies the final `.deb` package
- ✅ Uses the logo from `assets/photo_4949607461548043676_x.jpg`

## Prerequisites

### Required

- **Flutter SDK** (3.10.8 or higher)
- **dpkg-deb** (usually pre-installed on Debian/Ubuntu)

### Optional (but recommended)

- **ImageMagick** - For icon conversion and resizing
  ```bash
  sudo apt-get install imagemagick
  ```

### System Dependencies

The package will depend on:
- `libgtk-3-0`
- `libglib2.0-0`
- `libc6`
- `libstdc++6`
- `vlc` (required for video playback)

Recommended:
- `ffmpeg`

## Usage

### Quick Start

```bash
# Make the script executable (already done)
chmod +x build-deb.sh

# Run the build script
./build-deb.sh
```

### Build Process

The script will:

1. **Check Dependencies** - Verify Flutter and dpkg-deb are installed
2. **Clean Previous Builds** - Remove old build artifacts
3. **Build Flutter App** - Run `flutter build linux --release`
4. **Prepare Icon** - Convert logo to PNG and place in `/usr/share/pixmaps/`
5. **Prepare Structure** - Copy build to `debian-package/opt/screenscapetv/`
6. **Update Desktop File** - Create `.desktop` entry for application menu
7. **Create Control File** - Generate package metadata
8. **Create Scripts** - Generate post-install and post-remove scripts
9. **Fix Permissions** - Set correct file permissions
10. **Build Package** - Create the final `.deb` file
11. **Verify Package** - Show package contents and info

### Output

After successful build, you'll get:

```
screenscapetv_1.0.0-1_amd64.deb
```

Located in the project root directory.

## Installation

### Install the Package

```bash
# Install the .deb package
sudo dpkg -i screenscapetv_1.0.0-1_amd64.deb

# If there are dependency issues, fix them with:
sudo apt-get install -f
```

### Launch the Application

After installation, you can launch ScreenScapeTV in three ways:

1. **From Application Menu**: Look for "ScreenScapeTV" in your applications menu under "Audio & Video"

2. **From Terminal**:
   ```bash
   screenscapetv
   ```

3. **Direct Execution**:
   ```bash
   /opt/screenscapetv/screenscapetv
   ```

## Uninstallation

```bash
sudo apt-get remove screenscapetv
```

or

```bash
sudo dpkg -r screenscapetv
```

## Package Structure

After building, the package contains:

```
/
├── opt/
│   └── screenscapetv/
│       ├── screenscapetv           (main executable)
│       ├── lib/                    (Flutter libraries)
│       └── data/                   (Flutter assets)
├── usr/
│   ├── bin/
│   │   └── screenscapetv -> /opt/screenscapetv/screenscapetv
│   └── share/
│       ├── applications/
│       │   └── screenscapetv.desktop
│       └── pixmaps/
│           └── screenscapetv.png   (application icon)
```

## Customization

### Change Version

Edit the script variables:

```bash
APP_VERSION="1.0.0"
BUILD_NUMBER="1"
```

### Change Maintainer

Edit:

```bash
MAINTAINER="Your Name <your.email@example.com>"
```

### Change Icon

Replace the logo file or update the path:

```bash
LOGO_SOURCE="$PROJECT_ROOT/assets/your_logo.jpg"
```

## Troubleshooting

### Flutter Build Fails

```bash
# Clean Flutter build cache
flutter clean
flutter pub get

# Then try again
./build-deb.sh
```

### Permission Denied

```bash
# Make sure script is executable
chmod +x build-deb.sh
```

### ImageMagick Not Found

The script will work without ImageMagick but won't convert the icon format. Install it for best results:

```bash
sudo apt-get install imagemagick
```

### Package Installation Fails

```bash
# Check for missing dependencies
sudo apt-get install -f

# Or manually install dependencies
sudo apt-get install libgtk-3-0 libglib2.0-0 vlc
```

### Icon Not Showing

If the icon doesn't appear in the application menu:

```bash
# Update icon cache
sudo gtk-update-icon-cache -f -t /usr/share/pixmaps

# Update desktop database
sudo update-desktop-database
```

## Advanced Usage

### Build for Different Architecture

Edit the script:

```bash
ARCHITECTURE="arm64"  # For ARM64
ARCHITECTURE="armhf"  # For ARM32
```

### Add Custom Dependencies

Edit the `create_control_file()` function:

```bash
Depends: libgtk-3-0, libglib2.0-0, libc6, libstdc++6, vlc, your-package
```

### Modify Post-Install Actions

Edit the `create_postinst_script()` function to add custom actions that run after installation.

## Verification

### Check Package Contents

```bash
dpkg -c screenscapetv_1.0.0-1_amd64.deb
```

### Check Package Info

```bash
dpkg -I screenscapetv_1.0.0-1_amd64.deb
```

### Test Installation in Docker

```bash
# Create a test container
docker run -it --rm ubuntu:22.04

# Inside container
apt-get update
apt-get install -y ./screenscapetv_1.0.0-1_amd64.deb
```

## Build Script Options

The script includes several functions that can be commented out if needed:

- `verify_package` - Skip final verification
- `prepare_icon` - Skip icon preparation
- `create_postinst_script` - Skip post-install script
- `create_postrm_script` - Skip post-remove script

## Distribution

### Upload to GitHub Releases

After building:

```bash
# Create a release on GitHub
gh release create v1.0.0 screenscapetv_1.0.0-1_amd64.deb
```

### Create Repository

For easier distribution, create a Debian repository. Users can then install with:

```bash
sudo add-apt-repository ppa:your-ppa
sudo apt-get update
sudo apt-get install screenscapetv
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build Debian Package

on:
  push:
    tags:
      - 'v*'

jobs:
  build-deb:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.8'
      
      - name: Install dependencies
        run: sudo apt-get install -y imagemagick
      
      - name: Build .deb package
        run: ./build-deb.sh
      
      - name: Upload to release
        uses: softprops/action-gh-release@v1
        with:
          files: screenscapetv_*.deb
```

## Support

For issues or questions:
- Check the [README.md](README.md) for application details
- Open an issue on GitHub
- Review the build log output for errors

## License

This build script is part of the ScreenScapeTV project. See the main project LICENSE for details.

---

**Built with ❤️ for Linux users**
