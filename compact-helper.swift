// Opens Device Hub and presses "Switch to compact window" (which also connects).
// Talks to Device Hub through the Accessibility API by process ID, because on
// macOS 27.0.1 both System Events and NSRunningApplication report Device Hub's
// pid wrongly (0 / -1), so it's found by scanning processes for its executable.
// Pass --dry-run to find the button without pressing it.
// Exit codes: 0 ok, 1 failure (message on stderr), 2 no Accessibility permission.

import AppKit
import ApplicationServices

let bundleID = "com.apple.dt.Devices"
let compactHelp = "Switch to compact window"

func fail(_ msg: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(code)
}

func attr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
}

func children(_ el: AXUIElement) -> [AXUIElement] {
    (attr(el, kAXChildrenAttribute) as? [AXUIElement]) ?? []
}

// Breadth-first search for the first element matching `match`.
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

func run(until deadline: TimeInterval, every step: TimeInterval = 0.01, _ body: () -> Bool) -> Bool {
    let end = Date().addingTimeInterval(deadline)
    while Date() < end {
        if body() { return true }
        Thread.sleep(forTimeInterval: step)
    }
    return false
}

if !AXIsProcessTrusted() {
    fail("This app doesn't have Accessibility permission.", code: 2)
}

let dryRun = CommandLine.arguments.contains("--dry-run")

// Find Device Hub's real pid by its executable path
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
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    p.arguments = ["-b", bundleID]
    try? p.run()
    p.waitUntilExit()
}

// Launch (or bring forward) Device Hub
openDeviceHub()
var pid: pid_t?
_ = run(until: 15) { pid = deviceHubPID(); return pid != nil }
guard let pid else { fail("Device Hub didn't start within 15 seconds (is Xcode installed?).") }

let axApp = AXUIElementCreateApplication(pid)
func bringToFront() { AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue) }
bringToFront()

// Wait for a window; if it's running with its window closed, reopen it like a Dock click
var window: AXUIElement?
var reopened = false
let start = Date()
let gotWindow = run(until: 15) {
    if let w = (attr(axApp, kAXWindowsAttribute) as? [AXUIElement])?.first {
        window = w
        return true
    }
    if !reopened && Date().timeIntervalSince(start) >= 1 {
        openDeviceHub()
        reopened = true
    }
    return false
}
guard gotWindow, let window else { fail("Device Hub didn't show a window within 15 seconds.") }

if (attr(window, kAXMinimizedAttribute) as? Bool) == true {
    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
}
bringToFront()

// Find the compact button, toolbar first (fast), then the whole window
func isCompactButton(_ el: AXUIElement) -> Bool {
    (attr(el, kAXRoleAttribute) as? String) == kAXButtonRole
        && (attr(el, kAXHelpAttribute) as? String) == compactHelp
}
let toolbar = find(in: window, limit: 500) { (attr($0, kAXRoleAttribute) as? String) == kAXToolbarRole }
var button: AXUIElement?
var tries = 0
_ = run(until: 5) {
    tries += 1
    if let tb = toolbar, tries < 15 {
        button = find(in: tb, isCompactButton)
    } else {
        button = find(in: window, isCompactButton)
    }
    return button != nil
}
guard let button else { fail("Compact button not found.") }
if dryRun { print("Found the compact button (dry run, not pressed)."); exit(0) }

if AXUIElementPerformAction(button, kAXPressAction as CFString) != .success {
    fail("Couldn't press the compact button.")
}
