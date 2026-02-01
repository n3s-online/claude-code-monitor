import Foundation

enum SessionState: Equatable, Sendable {
    case working   // Claude is actively processing (RED)
    case waiting   // Claude is waiting for user input (GREEN)
}

struct Session: Identifiable, Equatable, Sendable {
    let id: String
    let workingDirectory: String
    var state: SessionState
    let startedAt: Date
    var lastIdleAt: Date?  // nil when busy, set when idle

    var displayId: String {
        String(id.prefix(8)) + "..."
    }

    var displayDirectory: String {
        guard !workingDirectory.isEmpty else { return "" }
        let url = URL(fileURLWithPath: workingDirectory)
        return url.lastPathComponent
    }
}
