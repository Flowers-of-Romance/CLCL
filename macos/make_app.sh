#!/bin/sh
# Build CLCL.app bundle from the SwiftPM executable.
set -e
cd "$(dirname "$0")"

swift build -c release

APP=CLCL.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/release/CLCL "$APP/Contents/MacOS/CLCL"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>CLCL</string>
	<key>CFBundleIdentifier</key>
	<string>com.nakka.clcl.mac</string>
	<key>CFBundleName</key>
	<string>CLCL</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built $APP"
