# iPhone-Mirroring-Device-Hub
iPhone Mirroring Clone Using Xcode Device Hub. 

HOW TO USE:
  - Open "iPhone Mirroring (Device Hub)"
  - Wait for connection
  - Done.

HOW IT WORKS:
  - Application runs an AppleScript
  - AppleScript opens Device Hub and starts mirroring
  - Device Hub mirrors iPhone screen, with full control.

HOW TO INSTALL/SETUP:
  Requirements:
    - MacOS 27+(may work on older versions too, untested)
    - Xcode(must be a version that supports your iPhone's iOS version)
  Install:
    - Download the "iPhone Mirroring (Device Hub)" app from the latest release
    - Copy it into the Applications folder
    - Open a terminal and run "xatter -cr '/Applications/iPhone Mirroring (Device Hub)'"
  Setup:
    - Open Xcode, go to Xcode(in menu bar) -> Open Developer Tool -> Device Hub
    - In Device Hub, go to File(in menu bar) -> Pair Nearby Device
    - Follow instructions to pair phone, you know it worked if you see your iPhone in the left sidebar of the Device Hub app
    - Quit Device Hub, and open the iPhone "Mirroring (Device Hub)" app you installed earlier
    - If it launches and connects, you're done.
