#!/bin/sh
# Builds "iPhone Mirroring (Device Hub).app" into ./build.
# Pass --install to also copy it into /Applications.
#
# Signs with your Apple Development certificate if you have one (Xcode creates it
# when you sign in with your Apple ID). That keeps the Accessibility permission
# working across rebuilds. Without one it signs ad-hoc, and you have to re-add the
# app in Accessibility after every rebuild.
set -e
cd "$(dirname "$0")"

NAME="iPhone Mirroring (Device Hub)"
APP="build/$NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/iPhoneMirroring" iPhoneMirroring.swift
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>local.iphone-mirroring-device-hub</string>
	<key>CFBundleName</key><string>$NAME</string>
	<key>CFBundleExecutable</key><string>iPhoneMirroring</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>2.0</string>
	<key>CFBundleVersion</key><string>2</string>
	<key>LSMinimumSystemVersion</key><string>27.0</string>
	<key>LSUIElement</key><true/>
	<key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF

IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Built $APP (signed with: ${IDENTITY:-ad-hoc})"

if [ "$1" = "--install" ]; then
	rm -rf "/Applications/$NAME.app"
	ditto "$APP" "/Applications/$NAME.app"
	echo "Installed to /Applications/$NAME.app"
fi
