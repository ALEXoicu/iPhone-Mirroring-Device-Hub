// iPhone Mirroring (Device Hub)
//
// Opens Xcode's Device Hub in compact (mirroring) mode, which mirrors the iPhone
// with full control.
//
// Optional dimming: with `defaults write local.iphone-mirroring-device-hub
// DimWithShortcuts -bool true`, it runs the iPhone Shortcut "Dim" once the phone
// is unlocked, and "Undim" when the mirror window closes. Shortcuts are run over
// the Xcode connection with `devicectl`.
//
// Device Hub is driven through the Accessibility API by process ID, because on
// macOS 27.0.1 System Events and NSRunningApplication report its pid wrongly.
// Progress and errors are logged to ~/Library/Logs/iPhone Mirroring (Device Hub).log

import AppKit
import ApplicationServices

let deviceHubBundleID = "com.apple.dt.Devices"
let compactHelp = "Switch to compact window"
let dimShortcut = "Dim"
let undimShortcut = "Undim"

// MARK: - Logging and alerts

let logURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/iPhone Mirroring (Device Hub).log")

func log(_ message: String) {
    let line = "\(Date()) \(message)\n"
    if let handle = try? FileHandle(forWritingTo: logURL) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        try? handle.close()
    } else {
        try? line.write(to: logURL, atomically: true, encoding: .utf8)
    }
}

func fail(_ message: String, _ details: String = "", openSettings: Bool = false) -> Never {
    log("FAIL: \(message) \(details)")
    NSApp.activate()
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = details
    alert.addButton(withTitle: "OK")
    if openSettings { alert.addButton(withTitle: "Open Settings") }
    if alert.runModal() == .alertSecondButtonReturn {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    exit(1)
}

// MARK: - Waiting and running commands

/// Calls `body` until it returns true or `seconds` pass.
func waitFor(_ seconds: TimeInterval, every step: TimeInterval = 0.05, _ body: () -> Bool) -> Bool {
    let end = Date().addingTimeInterval(seconds)
    while Date() < end {
        if body() { return true }
        Thread.sleep(forTimeInterval: step)
    }
    return false
}

/// Calls `body` until it returns a value or `seconds` pass.
func waitForValue<T>(_ seconds: TimeInterval, every step: TimeInterval = 0.05, _ body: () -> T?) -> T? {
    var value: T?
    _ = waitFor(seconds, every: step) { value = body(); return value != nil }
    return value
}

@discardableResult
func run(_ path: String, _ args: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { log("couldn't run \(path): \(error)"); return -1 }
    p.waitUntilExit()
    return p.terminationStatus
}

// MARK: - iPhone (via devicectl)

struct Phone {
    let id: String
    let name: String
    let connected: Bool
}

/// Paired physical iPhones, or nil if devicectl itself failed.
func pairedPhones() -> [Phone]? {
    let out = FileManager.default.temporaryDirectory.appendingPathComponent("devicehub-\(getpid()).json")
    defer { try? FileManager.default.removeItem(at: out) }
    guard run("/usr/bin/xcrun", ["devicectl", "list", "devices", "--json-output", out.path]) == 0,
          let data = try? Data(contentsOf: out),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let devices = (json["result"] as? [String: Any])?["devices"] as? [[String: Any]]
    else { return nil }

    return devices.compactMap { d in
        let conn = d["connectionProperties"] as? [String: Any] ?? [:]
        let hw = d["hardwareProperties"] as? [String: Any] ?? [:]
        guard conn["pairingState"] as? String == "paired",
              hw["platform"] as? String == "iOS",
              hw["reality"] as? String == "physical",
              let id = d["identifier"] as? String
        else { return nil }
        let name = (d["deviceProperties"] as? [String: Any])?["name"] as? String ?? "your iPhone"
        return Phone(id: id, name: name, connected: conn["tunnelState"] as? String == "connected")
    }
}

/// Whether the iPhone is unlocked, or nil if devicectl failed. Shortcuts can only run while it's unlocked.
func isUnlocked(_ phone: Phone) -> Bool? {
    let out = FileManager.default.temporaryDirectory.appendingPathComponent("devicehub-lock-\(getpid()).json")
    defer { try? FileManager.default.removeItem(at: out) }
    guard run("/usr/bin/xcrun", ["devicectl", "device", "info", "lockState", "--device", phone.id,
                                 "--json-output", out.path]) == 0,
          let data = try? Data(contentsOf: out),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let locked = (json["result"] as? [String: Any])?["passcodeRequired"] as? Bool
    else { return nil }
    return !locked
}

func runShortcut(_ name: String, on phone: Phone) {
    let encoded = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? name
    let status = run("/usr/bin/xcrun", [
        "devicectl", "device", "process", "launch", "--device", phone.id,
        "--payload-url", "shortcuts://run-shortcut?name=\(encoded)", "com.apple.shortcuts",
    ])
    log("shortcut \(name) on \(phone.name): exit \(status)")
}

// MARK: - Device Hub (via Accessibility)

func attr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
}

func children(_ el: AXUIElement) -> [AXUIElement] {
    (attr(el, kAXChildrenAttribute) as? [AXUIElement]) ?? []
}

func windows(_ app: AXUIElement) -> [AXUIElement] {
    (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
}

/// Breadth-first search for the first element matching `match`.
func find(in root: AXUIElement, limit: Int = 5000, _ match: (AXUIElement) -> Bool) -> AXUIElement? {
    var queue = [root], seen = 0
    while !queue.isEmpty && seen < limit {
        let el = queue.removeFirst()
        seen += 1
        if match(el) { return el }
        queue.append(contentsOf: children(el))
    }
    return nil
}

func isCompactButton(_ el: AXUIElement) -> Bool {
    (attr(el, kAXRoleAttribute) as? String) == kAXButtonRole
        && (attr(el, kAXHelpAttribute) as? String) == compactHelp
}

/// Device Hub's real pid, found by its executable path.
func deviceHubPID() -> pid_t? {
    let n = proc_listallpids(nil, 0)
    var pids = [pid_t](repeating: 0, count: Int(n) + 64)
    let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
    var buf = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
    for pid in pids.prefix(Int(max(count, 0))) where pid > 0 {
        if proc_pidpath(pid, &buf, UInt32(buf.count)) > 0,
           String(cString: buf).hasSuffix("/DeviceHub.app/Contents/MacOS/DeviceHub") {
            return pid
        }
    }
    return nil
}

func openDeviceHub() {
    run("/usr/bin/open", ["-b", deviceHubBundleID])
}

// MARK: - App

final class Controller: NSObject, NSApplicationDelegate {
    var busy = false
    var phone: Phone?
    var wantsDim = false
    var dimmed = false
    var ticks = 0
    var hubPID: pid_t = 0
    var mirrorWindows: [AXUIElement] = []
    var misses = 0
    var watchTimer: Timer?

    func applicationDidFinishLaunching(_ note: Notification) { start() }

    // Opening the app again while it's running starts mirroring again.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        start()
        return false
    }

    func start() {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        log("start")

        if !AXIsProcessTrusted() {
            fail("iPhone Mirroring needs Accessibility permission.",
                 "Turn it on in System Settings > Privacy & Security > Accessibility, then open the app again.",
                 openSettings: true)
        }

        openDeviceHub()  // also prompts Xcode to connect to the iPhone
        phone = waitForPhone()

        guard let pid = waitForValue(15, { deviceHubPID() }) else {
            fail("Device Hub didn't start.", "Is Xcode installed in the Applications folder?")
        }
        let hub = AXUIElementCreateApplication(pid)
        let bringToFront = { _ = AXUIElementSetAttributeValue(hub, kAXFrontmostAttribute as CFString, kCFBooleanTrue) }
        bringToFront()

        // Wait for a window; if Device Hub is running with its window closed, reopen it like a Dock click.
        var reopened = false
        let began = Date()
        guard let window = waitForValue(15, { () -> AXUIElement? in
            if let w = windows(hub).first { return w }
            if !reopened && Date().timeIntervalSince(began) >= 1 {
                openDeviceHub()
                reopened = true
            }
            return nil
        }) else {
            fail("Device Hub didn't show a window.")
        }
        if (attr(window, kAXMinimizedAttribute) as? Bool) == true {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        bringToFront()

        // Press "Switch to compact window". No button means it's already in compact mode.
        let before = windows(hub)
        let button = waitForValue(4, every: 0.1) { () -> AXUIElement? in
            for w in windows(hub) {
                if let b = find(in: w, isCompactButton) { return b }
            }
            return nil
        }
        if let button {
            guard AXUIElementPerformAction(button, kAXPressAction as CFString) == .success else {
                fail("Couldn't switch Device Hub to the compact window.")
            }
            log("pressed compact button")
            Thread.sleep(forTimeInterval: 1)
        } else {
            log("no compact button; assuming Device Hub is already in compact mode")
        }

        // The mirror is whichever window appeared after pressing, or the one that turned compact.
        let after = windows(hub)
        let added = after.filter { w in !before.contains { CFEqual($0, w) } }
        mirrorWindows = added.isEmpty ? after : added
        hubPID = pid
        misses = 0

        // check() runs Dim once the iPhone is unlocked.
        wantsDim = UserDefaults.standard.bool(forKey: "DimWithShortcuts") && phone != nil && !mirrorWindows.isEmpty

        watchTimer?.invalidate()
        watchTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.check() }
    }

    func waitForPhone() -> Phone? {
        var found: Phone?
        var known: [Phone]?
        _ = waitFor(20, every: 1) {
            known = pairedPhones()
            guard let phones = known, !phones.isEmpty else { return true }  // nothing to wait for
            found = phones.first(where: \.connected)
            return found != nil
        }
        if let found { return found }
        guard let phones = known else {
            log("devicectl failed; mirroring without dimming")
            return nil
        }
        if phones.isEmpty {
            fail("No paired iPhone found.", "Pair it first: open Device Hub, then choose File > Pair Nearby Device.")
        }
        fail("Can't reach \(phones[0].name).",
             "Unlock it and check it's on the same Wi-Fi as this Mac with Bluetooth on, or connect it with a cable. Then open the app again.")
    }

    // Runs every second. Ends the session once the mirror window is gone (2 checks in a row, to
    // ignore hiccups). Until the iPhone is dimmed, also checks every other second whether it's unlocked.
    func check() {
        let alive = kill(hubPID, 0) == 0
        let open = alive && windows(AXUIElementCreateApplication(hubPID)).contains { w in
            mirrorWindows.contains { CFEqual($0, w) }
        }
        misses = open ? 0 : misses + 1
        if misses >= 2 { finish() }

        ticks += 1
        if open, wantsDim, !dimmed, ticks % 2 == 0, let phone, isUnlocked(phone) == true {
            runShortcut(dimShortcut, on: phone)
            dimmed = true
        }
    }

    func finish() {
        watchTimer?.invalidate()
        log("mirror window closed")
        if let phone, dimmed {
            if isUnlocked(phone) == false {
                log("iPhone is locked; can't run \(undimShortcut)")
            } else {
                runShortcut(undimShortcut, on: phone)
            }
        }
        exit(0)
    }
}

let app = NSApplication.shared
let controller = Controller()
app.delegate = controller
app.setActivationPolicy(.accessory)
app.run()
