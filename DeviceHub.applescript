-- Device Hub: switch to compact window (this also connects to the selected device).
-- The work is done by compact-helper (bundled in Contents/Resources), which uses the
-- Accessibility API directly: on macOS 27.0.1 System Events can't see Device Hub's windows.
-- Needs Accessibility permission for this app.

try
	set helper to POSIX path of (path to me) & "Contents/Resources/compact-helper"
	do shell script quoted form of helper
on error errMsg number errNum
	if errNum is 2 then
		set errMsg to "This app doesn't have Accessibility permission. In System Settings > Privacy & Security > Accessibility, remove it with − and add it again."
	end if
	display dialog "Device Hub script failed: " & errMsg buttons {"OK"} default button "OK"
end try
