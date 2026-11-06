# iPhone-Mirroring-Device-Hub
iPhone Mirroring clone using Xcode's Device Hub. This is useful if you want iPhone Mirroring but can't use it because of region restrictions.

It works almost like real iPhone Mirroring. You can connect while the phone is locked, unlock it with your passcode from the Mac, and use it with your mouse and keyboard. Optionally, it can dim your iPhone's screen while you mirror it and restore it when you're done.

## How to use
- Open "iPhone Mirroring (Device Hub)".
- Your iPhone's screen appears in a small Device Hub window. If the phone is locked, unlock it with your passcode in that window.
- When you're done, close the mirror window.

## How it works
- The app uses Xcode's `devicectl` to check that your iPhone is paired and reachable.
- It opens Device Hub and presses "Switch to compact window" through the Accessibility API. Device Hub then mirrors the iPhone screen, with full control.
- If dimming is turned on, it runs a "Dim" Shortcut on the iPhone once it's unlocked, and an "Undim" Shortcut when you close the mirror window. Only the phone's own screen dims; the mirror on the Mac stays bright.
- Progress and errors are logged to `~/Library/Logs/iPhone Mirroring (Device Hub).log`.

## Requirements
- macOS 27 or later
- Xcode 27 or later, with support for your iPhone's iOS version
- An iPhone on iOS 27 or later (tested with iOS 27.0.1)

## Setup
1. **Pair your iPhone.** Open Xcode, go to Xcode (in the menu bar) → Open Developer Tool → Device Hub. In Device Hub, go to File → Pair Nearby Device and follow the instructions. It worked if your iPhone shows up in the left sidebar. Then quit Device Hub.
2. **Prepare your iPhone.** If asked, turn on Settings → Privacy & Security → Developer Mode. Then turn on Settings → Developer → Enable UI Automation, which lets the Mac send clicks and typing to the phone.
3. **Install the app** (see below).
4. **Give it Accessibility permission.** Open System Settings → Privacy & Security → Accessibility, press +, add "iPhone Mirroring (Device Hub)" from Applications, and turn it on.
5. **Open the app.** If it connects, you're done.

## Install
Build it from source:
```sh
git clone https://github.com/ALEXoicu/iPhone-Mirroring-Device-Hub.git
cd iPhone-Mirroring-Device-Hub
./build.sh --install
```
`build.sh` builds the app into `build/` and copies it to `/Applications`. If you have an Apple Development certificate (Xcode creates one when you add your Apple ID in Xcode → Settings → Accounts), it signs the app with it, so the Accessibility permission keeps working after rebuilds. Otherwise the app is signed ad-hoc, and you need to remove it from Accessibility and add it again after every rebuild.

Or download the app from the latest release, copy it into Applications, and run:
```sh
xattr -cr "/Applications/iPhone Mirroring (Device Hub).app"
```

## Dimming the iPhone (optional)
Device Hub mirrors the iPhone's actual screen, so the phone's screen can't be fully off while you mirror it. Instead, the app can dim it to almost black with two Shortcuts on the iPhone:

1. In the Shortcuts app on the iPhone, create a Shortcut named **Dim** with:
   - Set Brightness to 0%
   - Optional: Set Reduce White Point to On (makes it darker, if your iOS has this action)
   - Optional: Go to Home Screen (so you don't end up in the Shortcuts app)
2. Create a Shortcut named **Undim** with:
   - Set Brightness to your usual level
   - Set Reduce White Point to Off, if you used it in Dim
   - Lock Screen (the iPhone doesn't lock itself while it's being mirrored)
3. Turn dimming on, in Terminal:
   ```sh
   defaults write local.iphone-mirroring-device-hub DimWithShortcuts -bool true
   ```
   To turn it off again, use `-bool false`.

Shortcuts can only run while the iPhone is unlocked. The app waits until you've unlocked the phone before dimming it. When you're done, close the mirror window before locking the phone, otherwise Undim can't run and the phone stays dimmed.

## Troubleshooting
- **"Can't reach your iPhone"**: unlock it, check it's on the same Wi-Fi as the Mac with Bluetooth on, or connect it with a cable once.
- **The mirror shows, but clicks and typing don't work**: turn on Settings → Developer → Enable UI Automation on the iPhone, quit Device Hub, and open the app again.
- **The mirror window is black**: the iPhone's screen is off. Wake it with the button in Device Hub's window.
- **The app says it doesn't have Accessibility permission, but it's turned on**: remove it from the Accessibility list with − and add it again.
- **Anything else**: check `~/Library/Logs/iPhone Mirroring (Device Hub).log`.

## Files
- `iPhoneMirroring.swift`: the app.
- `build.sh`: builds and installs the app.
- `AppIcon.icns`: the app icon.
- `original-outdated.applescript`: the original 1.0 script (compiled AppleScript), kept for reference.
