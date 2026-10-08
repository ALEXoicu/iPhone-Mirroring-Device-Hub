# iPhone-Mirroring-Device-Hub
iPhone Mirroring Clone Using Xcode Device Hub. This is very useful for people who want to use iPhone Mirroring but don’t have access to it because of region restrictions.

It works almost the same as real iPhone Mirroring. You can connect while locked, unlock it via passcode through mirroring and use your phone to quickly check messages or notifications.

HOW TO USE:
  - Open "iPhone Mirroring (Device Hub)"
  - Wait for connection(shouldn't take more than like 1 second)
  - Done.


HOW IT WORKS:
  - Application runs an AppleScript
  - AppleScript opens a Swift helper(required for newer macOS)
  - Swift helper opens Device Hub and starts mirroring
  - Device Hub mirrors iPhone screen, with full control.


HOW TO INSTALL/SETUP:
  - Requirements:
    - MacOS 27+(may work on older versions too, untested)
    - Xcode(must be a version that supports your iPhone's iOS version)
  - Install:
    - Download the "iPhone Mirroring (Device Hub)" app from the latest release
    - Copy it into the Applications folder
    - Open a terminal and run "xatter -cr '/Applications/iPhone Mirroring (Device Hub)'"
    - Open Settings, go to Privacy & Security, go to Accessibility(or "Device Control" in newer macOS), press the + icon, add the app you installed earlier, enable it.
  - Setup:
    - Open Xcode, go to Xcode(in menu bar) -> Open Developer Tool -> Device Hub
    - In Device Hub, go to File(in menu bar) -> Pair Nearby Device
    - Follow instructions to pair phone, you know it worked if you see your iPhone in the left sidebar of the Device Hub app
    - Quit Device Hub, and open the iPhone "Mirroring (Device Hub)" app you installed earlier
    - If it launches and connects, you're done.
