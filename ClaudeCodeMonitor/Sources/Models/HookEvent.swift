import Foundation
import Vapor

struct HookEvent: Content, Sendable {
    let sessionId: String
    let eventType: EventType
    let workingDirectory: String?
    let timestamp: Date?
    let pid: Int32?  // Process ID of Claude Code instance

    enum EventType: String, Codable, Sendable {
        case sessionStart = "SessionStart"
        case sessionEnd = "SessionEnd"
        case notification = "Notification"
        case userPromptSubmit = "UserPromptSubmit"
        case postToolUse = "PostToolUse"
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case eventType = "event_type"
        case workingDirectory = "working_directory"
        case timestamp
        case pid
    }
}
