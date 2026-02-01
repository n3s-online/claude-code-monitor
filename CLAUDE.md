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
- **Session Store** - In-memory @MainActor storage with Combine pub/sub, 4-hour idle timeout cleanup. (`Services/SessionStore.swift`)
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

Add to `~/.claude/settings.json` to send events:

```json
{
  "hooks": {
    "SessionStart": [{"type": "command", "command": "curl -s -X POST http://localhost:7779/event -H 'Content-Type: application/json' -d '{\"session_id\": \"$CLAUDE_SESSION_ID\", \"event_type\": \"SessionStart\", \"working_directory\": \"'$(pwd)'\"}'"}],
    "Notification": [{"type": "command", "command": "curl -s -X POST http://localhost:7779/event -H 'Content-Type: application/json' -d '{\"session_id\": \"$CLAUDE_SESSION_ID\", \"event_type\": \"Notification\"}'"}],
    "UserPromptSubmit": [{"type": "command", "command": "curl -s -X POST http://localhost:7779/event -H 'Content-Type: application/json' -d '{\"session_id\": \"$CLAUDE_SESSION_ID\", \"event_type\": \"UserPromptSubmit\"}'"}],
    "PostToolUse": [{"type": "command", "command": "curl -s -X POST http://localhost:7779/event -H 'Content-Type: application/json' -d '{\"session_id\": \"$CLAUDE_SESSION_ID\", \"event_type\": \"PostToolUse\"}'"}],
    "Stop": [{"type": "command", "command": "curl -s -X POST http://localhost:7779/event -H 'Content-Type: application/json' -d '{\"session_id\": \"$CLAUDE_SESSION_ID\", \"event_type\": \"SessionEnd\"}'"}]
  }
}
```

## See Also

- `docs/prd.md` - Full product requirements
