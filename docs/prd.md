# Claude Code Monitor - Product Requirements Document

## Overview

**Claude Code Monitor** is a native macOS application that displays a transparent, always-on-top overlay showing the status of all running Claude Code instances on the user's machine. The overlay provides at-a-glance visibility into which Claude Code sessions are active and what projects they're working on.

## Problem Statement

When running multiple Claude Code instances across different terminal windows or projects, it's difficult to track which instances are active without switching between windows. Users need a persistent, non-intrusive way to monitor Claude Code activity.

## Goals

- Provide real-time visibility into all running Claude Code instances
- Minimize distraction with a transparent, click-through overlay
- Work seamlessly over fullscreen applications
- Zero configuration required after initial setup

## Non-Goals (MVP)

- Controlling or interacting with Claude Code instances from the overlay
- Historical session data or logging
- Detailed activity metrics or token usage
- Cross-device synchronization
- Custom themes or extensive visual customization
- Automatic hook installation (user configures manually)

---

## Requirements

### Functional Requirements

#### FR-1: Session Display
- Display one row per active Claude Code instance
- Each row shows:
  - **Session ID**: Truncated unique identifier (e.g., `abc123...`)
  - **Status**: Running indicator (visual, e.g., pulsing dot)
  - **Working Directory**: Project folder name (basename of cwd)
- Rows are removed immediately when a session ends

#### FR-2: Overlay Window
- Window positioned in top-left corner of primary display
- Fixed position (not draggable in MVP)
- Always visible, including over fullscreen applications
- Very transparent (20-40% opacity) with macOS vibrancy blur effect
- Click-through by default (mouse events pass to apps behind)
- Hold modifier key (Cmd) to enable interaction with overlay

#### FR-3: Claude Code Integration
- Receive events via HTTP POST from Claude Code hooks
- Listen on configurable localhost port (default: `7779`)
- Handle events:
  - `SessionStart`: Add new session row
  - `Stop`: Remove session row
- Parse JSON payload containing session_id and working directory

#### FR-4: Application Lifecycle
- Regular macOS dock application
- User manually launches when needed
- Overlay appears when app is running
- When no active sessions, display "No active sessions" message
- Requires macOS 15 Sequoia or later

### Non-Functional Requirements

#### NFR-1: Performance
- Overlay rendering must not impact system performance
- HTTP server must handle concurrent hook events
- Memory footprint under 50MB

#### NFR-2: Reliability
- Gracefully handle malformed hook payloads
- Auto-cleanup stale sessions if hook events are missed
- No crashes from unexpected input

#### NFR-3: User Experience
- Overlay must not interfere with normal computer use
- Sub-100ms latency from hook event to UI update
- Respect system appearance (light/dark mode)

---

## Technical Architecture

### Technology Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Application | Swift / SwiftUI | Native macOS, fullscreen overlay support, vibrancy effects |
| Window Management | AppKit (NSWindow) | Required for window level control, click-through behavior |
| HTTP Server | Swift NIO or Vapor (lightweight) | Native Swift, low overhead |
| Data Flow | Combine | Reactive updates from server to UI |

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        macOS System                             │
│                                                                 │
│  ┌─────────────────┐         ┌─────────────────────────────┐   │
│  │  Claude Code    │         │    Claude Code Monitor      │   │
│  │   Instance 1    │         │                             │   │
│  │                 │ HTTP    │  ┌───────────────────────┐  │   │
│  │  hooks/         │ POST    │  │    HTTP Server        │  │   │
│  │  SessionStart   │────────▶│  │    localhost:7779     │  │   │
│  │  Stop           │         │  └───────────┬───────────┘  │   │
│  └─────────────────┘         │              │              │   │
│                              │              ▼              │   │
│  ┌─────────────────┐         │  ┌───────────────────────┐  │   │
│  │  Claude Code    │         │  │    Session Store      │  │   │
│  │   Instance 2    │ HTTP    │  │    (in-memory)        │  │   │
│  │                 │ POST    │  └───────────┬───────────┘  │   │
│  │  hooks/         │────────▶│              │              │   │
│  │  SessionStart   │         │              ▼              │   │
│  │  Stop           │         │  ┌───────────────────────┐  │   │
│  └─────────────────┘         │  │   SwiftUI Overlay     │  │   │
│                              │  │   (NSWindow level)    │  │   │
│  ┌─────────────────┐         │  │                       │  │   │
│  │  Claude Code    │ HTTP    │  │   ┌─────────────────┐ │  │   │
│  │   Instance N    │ POST    │  │   │ abc12.. ● ~/proj│ │  │   │
│  │        ...      │────────▶│  │   │ def34.. ● ~/app │ │  │   │
│  └─────────────────┘         │  │   └─────────────────┘ │  │   │
│                              │  └───────────────────────┘  │   │
│                              └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Data Models

#### Session

```swift
struct Session: Identifiable {
    let id: String           // session_id from Claude Code
    let workingDirectory: String  // Full path
    let startedAt: Date

    var displayId: String {
        String(id.prefix(8)) + "..."
    }

    var displayDirectory: String {
        URL(fileURLWithPath: workingDirectory).lastPathComponent
    }
}
```

#### Hook Event Payload

```json
{
    "session_id": "uuid-string",
    "event_type": "SessionStart" | "Stop",
    "working_directory": "/Users/user/project",
    "timestamp": "2025-01-07T12:00:00Z"
}
```

### Window Configuration

```swift
// NSWindow configuration for overlay
window.level = .screenSaver  // Above fullscreen apps
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
window.isOpaque = false
window.backgroundColor = .clear
window.ignoresMouseEvents = true  // Click-through
window.alphaValue = 0.3  // 30% opacity base

// NSVisualEffectView for vibrancy
visualEffectView.material = .hudWindow
visualEffectView.blendingMode = .behindWindow
visualEffectView.state = .active
```

### API Endpoints

#### POST /event

Receives hook events from Claude Code.

**Request:**
```json
{
    "session_id": "abc123-def456",
    "event_type": "SessionStart",
    "working_directory": "/Users/willness/project"
}
```

**Response:**
```json
{
    "status": "ok"
}
```

#### GET /health

Health check endpoint for debugging.

**Response:**
```json
{
    "status": "healthy",
    "active_sessions": 3
}
```

---

## Claude Code Hook Configuration

Users must manually configure Claude Code hooks to send events to the monitor. This example configuration should be documented in the project README.

Add to `~/.claude/settings.json`:

```json
{
    "hooks": {
        "SessionStart": [
            {
                "type": "command",
                "command": "curl -s -X POST http://localhost:7779/event -H 'Content-Type: application/json' -d '{\"session_id\": \"$CLAUDE_SESSION_ID\", \"event_type\": \"SessionStart\", \"working_directory\": \"'$(pwd)'\"}'"
            }
        ],
        "Stop": [
            {
                "type": "command",
                "command": "curl -s -X POST http://localhost:7779/event -H 'Content-Type: application/json' -d '{\"session_id\": \"$CLAUDE_SESSION_ID\", \"event_type\": \"Stop\"}'"
            }
        ]
    }
}
```

---

## User Interface

### Overlay Layout

```
┌────────────────────────────────────┐
│  ● abc123...  ~/claude-code-monitor│
│  ● def456...  ~/other-project      │
│  ● ghi789...  ~/api-server         │
└────────────────────────────────────┘
```

- Green pulsing dot (●) indicates running status
- Session ID truncated to 8 chars + ellipsis
- Working directory shows folder name only
- Rows auto-size to content
- Empty state: displays "No active sessions" message

### Visual Design

- Background: macOS vibrancy blur (`.hudWindow` material)
- Text: SF Mono font, system label color (adapts to light/dark)
- Status indicator: Green (#34C759) pulsing circle
- Padding: 8pt horizontal, 4pt vertical per row
- Corner radius: 8pt
- Overall opacity: 30% (configurable for future)

---

## Testing Strategy

### Unit Tests

| Test Area | Description |
|-----------|-------------|
| Session Store | Add/remove sessions, handle duplicates, concurrent access |
| Event Parsing | Valid payloads, malformed JSON, missing fields |
| Display Logic | ID truncation, directory basename extraction |

### Integration Tests

| Test Area | Description |
|-----------|-------------|
| HTTP Server | Receive events, respond correctly, handle load |
| End-to-End | Hook fires → server receives → UI updates |

### Manual Testing

| Test Case | Steps |
|-----------|-------|
| Fullscreen overlay | Open fullscreen app, verify overlay visible |
| Click-through | Click through overlay, verify events pass to app behind |
| Modifier interaction | Hold Cmd, verify overlay becomes interactive |
| Multiple sessions | Start 3+ Claude instances, verify all displayed |
| Session cleanup | Stop instance, verify row removed immediately |

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Hook events missed | Stale sessions shown | Implement heartbeat or periodic cleanup |
| Port conflict | App fails to start | Allow configurable port, show clear error |
| macOS permissions | Overlay not visible | Document accessibility permissions if needed |
| High CPU from polling | Battery drain | Use event-driven architecture, no polling |

---

## Future Considerations (Post-MVP)

- Configurable position (drag to any corner)
- Adjustable transparency slider
- Show current tool being used
- Click row to focus Claude instance terminal
- Session duration timer
- Token usage display
- Menu bar mode option
- Multiple monitor support (show on specific display)
- Notification when instance completes long task

---

## Success Metrics

- Overlay renders within 100ms of app launch
- UI updates within 100ms of hook event
- Zero crashes in normal operation
- Memory usage under 50MB with 10 active sessions
- Works correctly over fullscreen Safari, VS Code, etc.

---

## Decisions

1. **Default port**: 7779
2. **Empty state**: Show "No active sessions" message (overlay remains visible)
3. **Hook installation**: Manual setup by user; example hook configuration provided in README
4. **Minimum macOS version**: macOS 15 Sequoia
