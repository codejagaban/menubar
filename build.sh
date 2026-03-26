#!/bin/bash
set -e

APP_NAME="MeetingBar"
BUNDLE_ID="com.codejagaban.meetingbar"
VERSION="1.0.0"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME v$VERSION..."

# Build release binary
swift build -c release

echo "Creating app bundle..."

# Create .app structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSCalendarsUsageDescription</key>
    <string>MeetingBar needs access to your calendars to display upcoming meetings in the menu bar.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>MeetingBar needs access to your calendars to display upcoming meetings in the menu bar.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Generate app icon from SF Symbol if iconutil is available
if command -v python3 &> /dev/null; then
    echo "Generating app icon..."
    python3 generate_icon.py "$APP_BUNDLE/Contents/Resources"
fi

# Copy icon if it exists
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc sign
echo "Signing app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "Build complete!"
echo "App bundle: $APP_BUNDLE"
echo ""
echo "To install, run:"
echo "  cp -r \"$APP_BUNDLE\" /Applications/"
echo "Creating DMG..."
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -r "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$BUILD_DIR/$APP_NAME.dmg"
rm -rf "$DMG_STAGING"

echo ""
echo "DMG: $BUILD_DIR/$APP_NAME.dmg"
