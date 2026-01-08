import Foundation
import Vapor

struct HookEvent: Content, Sendable {
    let sessionId: String
    let eventType: EventType
    let workingDirectory: String?
    let timestamp: Date?
    let state: StateValue?

    enum EventType: String, Codable, Sendable {
        case sessionStart = "SessionStart"
        case stop = "Stop"
        case stateChange = "StateChange"
    }

    enum StateValue: String, Codable, Sendable {
        case working
        case waiting
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case eventType = "event_type"
        case workingDirectory = "working_directory"
        case timestamp
        case state
    }
}
