import Testing
import Foundation
@testable import ClaudeCodeMonitor

@Suite("HookEvent Parsing Tests")
struct HookEventParsingTests {
    @Test("parses valid SessionStart payload")
    func parsesSessionStart() throws {
        let json = """
        {
            "session_id": "abc-123",
            "event_type": "SessionStart",
            "working_directory": "/Users/test/project"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)

        #expect(event.sessionId == "abc-123")
        #expect(event.eventType == .sessionStart)
        #expect(event.workingDirectory == "/Users/test/project")
        #expect(event.timestamp == nil)
    }

    @Test("parses valid SessionEnd payload")
    func parsesSessionEnd() throws {
        let json = """
        {
            "session_id": "abc-123",
            "event_type": "SessionEnd"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)

        #expect(event.sessionId == "abc-123")
        #expect(event.eventType == .sessionEnd)
        #expect(event.workingDirectory == nil)
    }

    @Test("parses payload with timestamp")
    func parsesWithTimestamp() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let json = """
        {
            "session_id": "abc-123",
            "event_type": "SessionStart",
            "working_directory": "/tmp",
            "timestamp": "2026-01-07T12:00:00Z"
        }
        """.data(using: .utf8)!

        let event = try decoder.decode(HookEvent.self, from: json)

        #expect(event.sessionId == "abc-123")
        #expect(event.timestamp != nil)
    }

    @Test("fails on missing session_id")
    func failsMissingSessionId() {
        let json = """
        {
            "event_type": "SessionStart"
        }
        """.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(HookEvent.self, from: json)
        }
    }

    @Test("fails on missing event_type")
    func failsMissingEventType() {
        let json = """
        {
            "session_id": "abc-123"
        }
        """.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(HookEvent.self, from: json)
        }
    }

    @Test("fails on invalid event_type")
    func failsInvalidEventType() {
        let json = """
        {
            "session_id": "abc-123",
            "event_type": "InvalidType"
        }
        """.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(HookEvent.self, from: json)
        }
    }

    @Test("fails on malformed JSON")
    func failsMalformedJson() {
        let json = "not valid json".data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(HookEvent.self, from: json)
        }
    }

    @Test("parses payload with PID")
    func parsesWithPid() throws {
        let json = """
        {
            "session_id": "abc-123",
            "event_type": "SessionStart",
            "working_directory": "/tmp",
            "pid": 12345
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)

        #expect(event.sessionId == "abc-123")
        #expect(event.pid == 12345)
    }

    @Test("parses payload without PID")
    func parsesWithoutPid() throws {
        let json = """
        {
            "session_id": "abc-123",
            "event_type": "SessionStart",
            "working_directory": "/tmp"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)

        #expect(event.sessionId == "abc-123")
        #expect(event.pid == nil)
    }

    @Test("parses payload with null PID")
    func parsesWithNullPid() throws {
        let json = """
        {
            "session_id": "abc-123",
            "event_type": "SessionStart",
            "working_directory": "/tmp",
            "pid": null
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(HookEvent.self, from: json)

        #expect(event.sessionId == "abc-123")
        #expect(event.pid == nil)
    }
}
