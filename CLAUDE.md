# Claude Code Monitor

macOS overlay app that displays status of all running Claude Code instances. Receives webhook events from Claude hooks, shows transparent always-on-top overlay with session states.

## Architecture

- **Stack**: Swift 6 / SwiftUI / Vapor / AppKit
- **Platform**: macOS 15+
- `Sources/Models/` - Data: `Session`, `HookEvent`
- `Sources/Services/` - Business logic: `SessionStore` (@MainActor), `HTTPServer` (Vapor)
- `Sources/Views/` - UI: `OverlayView`, `SessionRowView`, `PulsingDotView`
- `AppDelegate.swift` - Window setup, keyboard monitoring, lifecycle

## Development

```bash
# Build & run
./run.sh
# Or manually:
cd ClaudeCodeMonitor && swift build && .build/debug/ClaudeCodeMonitor

# Test
cd ClaudeCodeMonitor && swift test
```

No code signing required for local dev. HTTP server runs on `localhost:7779`.

## Features

- **Webhook Server** - Vapor on :7779, POST `/event` receives hook events, GET `/health` for status with session list. (`Services/HTTPServer.swift`)
- **Session Store** - In-memory @MainActor storage with Combine pub/sub, process-based cleanup (10-second check interval). (`Services/SessionStore.swift`)
- **Process Tracking** - Sessions include Claude Code PID; dead processes are automatically cleaned up within 10 seconds. Untracked sessions (no PID) persist until explicit SessionEnd event.
- **Overlay Window** - Borderless, .screenSaver level, click-through (Cmd enables interaction). (`AppDelegate.swift`, `Views/OverlayView.swift`)
- **Status Indicators** - Pulsing dots: red=working (0.4s), green=waiting (0.8s). (`Views/PulsingDotView.swift`)

## Event Types

| Event | State | Description |
|-------|-------|-------------|
| `SessionStart` | idle | New session registered |
| `SessionEnd` | removed | Session terminated |
| `Notification` | idle | Claude finished, waiting for user |
| `UserPromptSubmit` | busy | User submitted prompt |
| `PostToolUse` | busy | Tool execution completed |

## Hook Configuration

Add to `~/.claude/settings.json` to send events. Hooks receive context via JSON on stdin, so we use `jq` to extract `session_id` and pipe to curl. The `$PPID` environment variable captures the Claude Code process ID for automatic cleanup when the process exits. Errors are suppressed so the monitor can be stopped without cluttering CC sessions:

```json
{
  "hooks": {
    "SessionStart": [{"matcher": "", "hooks": [{"type": "command", "command": "jq -c --arg pid \"$PPID\" '{session_id: .session_id, event_type: \"SessionStart\", working_directory: .cwd, pid: ($pid | tonumber)}' | curl -s -X POST http://localhost:7779/event -H 'Content-Type: application/json' -d @- 2>/dev/null || true"}]}],
    "Notification": [{"matcher": "", "hooks": [{"type": "command", "command": "jq -c --arg pid \"$PPID\" '{session_id: .session_id, event_type: \"Notification\", working_directory: .cwd, pid: ($pid | tonumber)}' | curl -s -X POST http://localhost:7779/event -H 'Content-Type: application/json' -d @- 2>/dev/null || true"}]}],
    "UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": "jq -c --arg pid \"$PPID\" '{session_id: .session_id, event_type: \"UserPromptSubmit\", working_directory: .cwd, pid: ($pid | tonumber)}' | curl -s -X POST http://localhost:7779/event -H 'Content-Type: application/json' -d @- 2>/dev/null || true"}]}],
    "PostToolUse": [{"matcher": "", "hooks": [{"type": "command", "command": "jq -c --arg pid \"$PPID\" '{session_id: .session_id, event_type: \"PostToolUse\", working_directory: .cwd, pid: ($pid | tonumber)}' | curl -s -X POST http://localhost:7779/event -H 'Content-Type: application/json' -d @- 2>/dev/null || true"}]}],
    "Stop": [{"matcher": "", "hooks": [{"type": "command", "command": "jq -c --arg pid \"$PPID\" '{session_id: .session_id, event_type: \"SessionEnd\", working_directory: .cwd, pid: ($pid | tonumber)}' | curl -s -X POST http://localhost:7779/event -H 'Content-Type: application/json' -d @- 2>/dev/null || true"}]}]
  }
}
```

**Note**: `$PPID` is the parent process ID of the hook command, which is the Claude Code process. The `jq` argument `--arg pid "$PPID"` passes it as a string, then `($pid | tonumber)` converts it to a number in the JSON output.

## See Also

- `docs/prd.md` - Full product requirements
