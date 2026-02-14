#!/bin/bash

# ScreenScapeTV - Debian Package Builder
# This script builds a .deb package for Linux distributions

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="screenscapetv"
APP_VERSION="1.0.1"
BUILD_NUMBER="1"
ARCHITECTURE="amd64"
MAINTAINER="ScreenScapeTV <hunternisha55@gmail.com>"
DESCRIPTION="Multi-provider streaming application for movies and TV shows"

# Paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/linux/x64/release/bundle"
DEBIAN_DIR="$PROJECT_ROOT/debian-package"
LOGO_SOURCE="$PROJECT_ROOT/assets/icon.png"
ICON_DEST_DIR="$DEBIAN_DIR/usr/share/pixmaps"
ICON_DEST_FILE="$ICON_DEST_DIR/${APP_NAME}.png"

# Print colored message
print_message() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Print section header
print_header() {
    echo ""
    print_message "$BLUE" "═══════════════════════════════════════════════════════"
    print_message "$BLUE" "  $1"
    print_message "$BLUE" "═══════════════════════════════════════════════════════"
    echo ""
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check dependencies
check_dependencies() {
    print_header "Checking Dependencies"
    
    local missing_deps=()
    
    if ! command_exists flutter; then
        missing_deps+=("flutter")
    fi
    
    if ! command_exists dpkg-deb; then
        missing_deps+=("dpkg-deb")
    fi
    
    if ! command_exists convert; then
        print_message "$YELLOW" "⚠ ImageMagick not found. Will skip icon conversion."
        print_message "$YELLOW" "  Install with: sudo apt-get install imagemagick"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_message "$RED" "✗ Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    print_message "$GREEN" "✓ All required dependencies found"
}

# Clean previous builds
clean_build() {
    print_header "Cleaning Previous Builds"
    
    if [ -d "$BUILD_DIR" ]; then
        print_message "$YELLOW" "Removing old build directory..."
        rm -rf "$BUILD_DIR"
    fi
    
    if [ -d "$DEBIAN_DIR/opt/$APP_NAME" ]; then
        print_message "$YELLOW" "Cleaning debian package directory..."
        rm -rf "$DEBIAN_DIR/opt/$APP_NAME"/*
    fi
    
    print_message "$GREEN" "✓ Cleanup complete"
}

# Build Flutter application
build_flutter_app() {
    print_header "Building Flutter Application"
    
    print_message "$BLUE" "Running: flutter build linux --release"
    
    if flutter build linux --release; then
        print_message "$GREEN" "✓ Flutter build successful"
    else
        print_message "$RED" "✗ Flutter build failed"
        exit 1
    fi
    
    # Verify build output exists
    if [ ! -d "$BUILD_DIR" ]; then
        print_message "$RED" "✗ Build directory not found: $BUILD_DIR"
        exit 1
    fi
    
    print_message "$GREEN" "✓ Build output verified"
}

# Prepare icon
prepare_icon() {
    print_header "Preparing Application Icon"
    
    # Create pixmaps directory
    mkdir -p "$ICON_DEST_DIR"
    
    if [ ! -f "$LOGO_SOURCE" ]; then
        print_message "$RED" "✗ Logo file not found: $LOGO_SOURCE"
        exit 1
    fi
    
    print_message "$BLUE" "Converting logo to PNG format..."
    
    # Convert JPG to PNG and resize if ImageMagick is available
    if command_exists convert; then
        if convert "$LOGO_SOURCE" -resize 512x512 "$ICON_DEST_FILE" 2>/dev/null; then
            print_message "$GREEN" "✓ Icon converted and resized: $ICON_DEST_FILE"
        else
            print_message "$YELLOW" "⚠ ImageMagick conversion failed, copying original..."
            cp "$LOGO_SOURCE" "$ICON_DEST_FILE"
        fi
    else
        # Just copy the original file
        print_message "$YELLOW" "⚠ ImageMagick not available, copying original logo..."
        cp "$LOGO_SOURCE" "${ICON_DEST_FILE%.png}.jpg"
        ICON_DEST_FILE="${ICON_DEST_FILE%.png}.jpg"
    fi
    
    # Also create a symlink in the bundle for the desktop file
    local bundle_icon_dir="$DEBIAN_DIR/opt/$APP_NAME/data/flutter_assets/assets"
    mkdir -p "$bundle_icon_dir"
    cp "$LOGO_SOURCE" "$bundle_icon_dir/icon.png" 2>/dev/null || \
        cp "$LOGO_SOURCE" "$bundle_icon_dir/icon.jpg"
    
    print_message "$GREEN" "✓ Icon preparation complete"
}

# Copy Flutter build to debian structure
prepare_debian_structure() {
    print_header "Preparing Debian Package Structure"
    
    # Create necessary directories
    mkdir -p "$DEBIAN_DIR/opt/$APP_NAME"
    mkdir -p "$DEBIAN_DIR/usr/bin"
    mkdir -p "$DEBIAN_DIR/usr/share/applications"
    mkdir -p "$DEBIAN_DIR/DEBIAN"
    
    print_message "$BLUE" "Copying Flutter build to /opt/$APP_NAME..."
    
    # Copy the entire bundle
    cp -r "$BUILD_DIR"/* "$DEBIAN_DIR/opt/$APP_NAME/"
    
    # Create symlink in /usr/bin
    print_message "$BLUE" "Creating symlink in /usr/bin..."
    ln -sf "/opt/$APP_NAME/$APP_NAME" "$DEBIAN_DIR/usr/bin/$APP_NAME"
    
    print_message "$GREEN" "✓ Debian structure prepared"
}

# Update desktop file
update_desktop_file() {
    print_header "Updating Desktop File"
    
    local desktop_file="$DEBIAN_DIR/usr/share/applications/${APP_NAME}.desktop"
    local icon_name="${APP_NAME}"
    
    # Determine icon extension
    if [ -f "$ICON_DEST_DIR/${APP_NAME}.png" ]; then
        icon_name="${APP_NAME}"
    elif [ -f "$ICON_DEST_DIR/${APP_NAME}.jpg" ]; then
        icon_name="${APP_NAME}"
    fi
    
    cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=ScreenScapeTV
Comment=Multi-provider streaming application for movies and TV shows
Exec=/opt/${APP_NAME}/${APP_NAME}
Icon=${icon_name}
Terminal=false
Categories=AudioVideo;Video;Player;Network;
Keywords=streaming;movies;tv;video;player;
StartupNotify=true
StartupWMClass=${APP_NAME}
EOF
    
    chmod 644 "$desktop_file"
    
    print_message "$GREEN" "✓ Desktop file updated"
}

# Create DEBIAN control file
create_control_file() {
    print_header "Creating Control File"
    
    local control_file="$DEBIAN_DIR/DEBIAN/control"
    
    cat > "$control_file" << EOF
Package: $APP_NAME
Version: $APP_VERSION-$BUILD_NUMBER
Section: video
Priority: optional
Architecture: $ARCHITECTURE
Maintainer: $MAINTAINER
Depends: libgtk-3-0, libglib2.0-0, libc6, libstdc++6, vlc
Recommends: ffmpeg
Description: $DESCRIPTION
 ScreenScapeTV is a Flutter-based multi-provider streaming application
 that aggregates content from various movie and TV show providers.
 .
 Features:
  - 15+ content providers
  - Global search across all providers
  - TV-optimized interface with D-Pad support
  - Multiple stream quality options
  - VLC integration for playback
  - Built-in video player
  - Cross-platform support
Homepage: https://github.com/Anshu78780/screenscapetv
EOF
    
    chmod 644 "$control_file"
    
    print_message "$GREEN" "✓ Control file created"
}

# Create postinst script
create_postinst_script() {
    print_header "Creating Post-Install Script"
    
    local postinst_file="$DEBIAN_DIR/DEBIAN/postinst"
    
    cat > "$postinst_file" << 'EOF'
#!/bin/bash
set -e

# Update desktop database
if which update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q
fi

# Update icon cache
if which gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/pixmaps 2>/dev/null || true
fi

# Set executable permissions
chmod +x /opt/screenscapetv/screenscapetv

echo "ScreenScapeTV installed successfully!"
echo "You can now launch it from your application menu or run 'screenscapetv' from terminal."

exit 0
EOF
    
    chmod 755 "$postinst_file"
    
    print_message "$GREEN" "✓ Post-install script created"
}

# Create postrm script
create_postrm_script() {
    print_header "Creating Post-Remove Script"
    
    local postrm_file="$DEBIAN_DIR/DEBIAN/postrm"
    
    cat > "$postrm_file" << 'EOF'
#!/bin/bash
set -e

# Update desktop database
if which update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q
fi

# Update icon cache
if which gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f /usr/share/pixmaps 2>/dev/null || true
fi

echo "ScreenScapeTV has been removed."

exit 0
EOF
    
    chmod 755 "$postrm_file"
    
    print_message "$GREEN" "✓ Post-remove script created"
}

# Fix permissions
fix_permissions() {
    print_header "Fixing Permissions"
    
    # Set correct permissions
    find "$DEBIAN_DIR" -type d -exec chmod 755 {} \;
    find "$DEBIAN_DIR" -type f -exec chmod 644 {} \;
    
    # Make executable files executable
    chmod 755 "$DEBIAN_DIR/opt/$APP_NAME/$APP_NAME"
    
    # Make DEBIAN scripts executable
    if [ -f "$DEBIAN_DIR/DEBIAN/postinst" ]; then
        chmod 755 "$DEBIAN_DIR/DEBIAN/postinst"
    fi
    if [ -f "$DEBIAN_DIR/DEBIAN/postrm" ]; then
        chmod 755 "$DEBIAN_DIR/DEBIAN/postrm"
    fi
    
    print_message "$GREEN" "✓ Permissions fixed"
}

# Build .deb package
build_deb_package() {
    print_header "Building .deb Package"
    
    local output_dir="$PROJECT_ROOT"
    local deb_file="${APP_NAME}_${APP_VERSION}-${BUILD_NUMBER}_${ARCHITECTURE}.deb"
    
    print_message "$BLUE" "Building package: $deb_file"
    
    # Remove old .deb if exists
    if [ -f "$output_dir/$deb_file" ]; then
        rm -f "$output_dir/$deb_file"
    fi
    
    # Build the package
    if dpkg-deb --build "$DEBIAN_DIR" "$output_dir/$deb_file"; then
        print_message "$GREEN" "✓ Package built successfully"
    else
        print_message "$RED" "✗ Package build failed"
        exit 1
    fi
    
    # Fix package file permissions (make it readable by all users)
    chmod 644 "$output_dir/$deb_file"
    print_message "$GREEN" "✓ Package permissions set correctly"
    
    # Get package info
    local size=$(du -h "$output_dir/$deb_file" | cut -f1)
    
    print_header "Build Complete!"
    print_message "$GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message "$GREEN" "  Package: $deb_file"
    print_message "$GREEN" "  Size: $size"
    print_message "$GREEN" "  Location: $output_dir"
    print_message "$GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_message "$BLUE" "To install, run:"
    print_message "$YELLOW" "  sudo dpkg -i $deb_file"
    print_message "$YELLOW" "  sudo apt-get install -f  # If dependencies are missing"
    echo ""
}

# Verify package
verify_package() {
    print_header "Verifying Package"
    
    local deb_file="${APP_NAME}_${APP_VERSION}-${BUILD_NUMBER}_${ARCHITECTURE}.deb"
    
    if [ -f "$PROJECT_ROOT/$deb_file" ]; then
        print_message "$BLUE" "Package contents:"
        dpkg -c "$PROJECT_ROOT/$deb_file" | head -20
        echo ""
        print_message "$BLUE" "Package info:"
        dpkg -I "$PROJECT_ROOT/$deb_file"
        print_message "$GREEN" "✓ Package verification complete"
    else
        print_message "$RED" "✗ Package file not found"
        exit 1
    fi
}

# Main execution
main() {
    clear
    print_message "$BLUE" "╔═══════════════════════════════════════════════════════╗"
    print_message "$BLUE" "║                                                       ║"
    print_message "$BLUE" "║         ScreenScapeTV - Debian Package Builder        ║"
    print_message "$BLUE" "║                    Version $APP_VERSION                     ║"
    print_message "$BLUE" "║                                                       ║"
    print_message "$BLUE" "╚═══════════════════════════════════════════════════════╝"
    echo ""
    
    # Run build steps
    check_dependencies
    clean_build
    build_flutter_app
    prepare_icon
    prepare_debian_structure
    update_desktop_file
    create_control_file
    create_postinst_script
    create_postrm_script
    fix_permissions
    build_deb_package
    verify_package
    
    print_message "$GREEN" "🎉 All done! Your .deb package is ready!"
    echo ""
}

# Run main function
main "$@"
