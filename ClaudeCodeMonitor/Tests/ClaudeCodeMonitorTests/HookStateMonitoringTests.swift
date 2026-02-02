import Testing
import Foundation
import Vapor
import VaporTesting
@testable import ClaudeCodeMonitor

/// Comprehensive tests for hook-based state monitoring.
/// Verifies that all 5 event types correctly transition session states.
@Suite("Hook-Based State Monitoring Tests")
struct HookStateMonitoringTests {
    // MARK: - Event Type State Transitions

    @Suite("Event Type State Transitions")
    @MainActor
    struct EventTypeStateTransitions {
        @Test("SessionStart event creates session in idle state")
        func sessionStartCreatesIdleSession() {
            let store = SessionStore()

            store.registerSession(id: "session-1", workingDirectory: "/project")

            #expect(store.sessionCount == 1)
            #expect(store.sessions.first?.state == .waiting)
            #expect(store.sessions.first?.lastIdleAt != nil)
        }

        @Test("SessionEnd event removes session")
        func sessionEndRemovesSession() {
            let store = SessionStore()
            store.registerSession(id: "session-1", workingDirectory: "/project")
            #expect(store.sessionCount == 1)

            store.removeSession(id: "session-1")

            #expect(store.sessionCount == 0)
        }

        @Test("Notification event sets session to idle state")
        func notificationSetsIdleState() {
            let store = SessionStore()
            store.registerSession(id: "session-1", workingDirectory: "/project")
            store.setBusy(id: "session-1")
            #expect(store.sessions.first?.state == .working)

            store.setIdle(id: "session-1")

            #expect(store.sessions.first?.state == .waiting)
            #expect(store.sessions.first?.lastIdleAt != nil)
        }

        @Test("UserPromptSubmit event sets session to busy state")
        func userPromptSubmitSetsBusyState() {
            let store = SessionStore()
            store.registerSession(id: "session-1", workingDirectory: "/project")
            #expect(store.sessions.first?.state == .waiting)

            store.setBusy(id: "session-1")

            #expect(store.sessions.first?.state == .working)
            #expect(store.sessions.first?.lastIdleAt == nil)
        }

        @Test("PostToolUse event sets session to busy state")
        func postToolUseSetsBusyState() {
            let store = SessionStore()
            store.registerSession(id: "session-1", workingDirectory: "/project")
            store.setIdle(id: "session-1")

            store.setBusy(id: "session-1")

            #expect(store.sessions.first?.state == .working)
            #expect(store.sessions.first?.lastIdleAt == nil)
        }
    }

    // MARK: - Full Lifecycle Tests

    @Suite("Session Lifecycle Tests")
    @MainActor
    struct SessionLifecycleTests {
        @Test("complete session lifecycle: start -> prompt -> notification -> tool -> notification -> end")
        func completeSessionLifecycle() {
            let store = SessionStore()

            // 1. Session starts (idle)
            store.registerSession(id: "lifecycle-session", workingDirectory: "/project")
            #expect(store.sessions.first?.state == .waiting)
            #expect(store.sessionCount == 1)

            // 2. User submits prompt (busy)
            store.setBusy(id: "lifecycle-session")
            #expect(store.sessions.first?.state == .working)

            // 3. Claude finishes, sends notification (idle)
            store.setIdle(id: "lifecycle-session")
            #expect(store.sessions.first?.state == .waiting)

            // 4. Claude uses a tool (busy)
            store.setBusy(id: "lifecycle-session")
            #expect(store.sessions.first?.state == .working)

            // 5. Tool completes, notification (idle)
            store.setIdle(id: "lifecycle-session")
            #expect(store.sessions.first?.state == .waiting)

            // 6. Session ends (removed)
            store.removeSession(id: "lifecycle-session")
            #expect(store.sessionCount == 0)
        }

        @Test("rapid busy-idle transitions maintain correct state")
        func rapidBusyIdleTransitions() {
            let store = SessionStore()
            store.registerSession(id: "rapid-session", workingDirectory: "/project")

            // Simulate rapid tool usage
            for _ in 0..<10 {
                store.setBusy(id: "rapid-session")
                #expect(store.sessions.first?.state == .working)

                store.setIdle(id: "rapid-session")
                #expect(store.sessions.first?.state == .waiting)
            }

            #expect(store.sessionCount == 1)
            #expect(store.sessions.first?.state == .waiting)
        }

        @Test("session persists across many state changes")
        func sessionPersistsAcrossStateChanges() {
            let store = SessionStore()
            store.registerSession(id: "persistent-session", workingDirectory: "/original/path")

            let originalStartedAt = store.sessions.first?.startedAt
            let originalWorkingDir = store.sessions.first?.workingDirectory

            // Many state changes
            for _ in 0..<50 {
                store.setBusy(id: "persistent-session")
                store.setIdle(id: "persistent-session")
            }

            // Session identity preserved
            #expect(store.sessions.first?.id == "persistent-session")
            #expect(store.sessions.first?.startedAt == originalStartedAt)
            #expect(store.sessions.first?.workingDirectory == originalWorkingDir)
        }
    }

    // MARK: - Auto-Registration Tests

    @Suite("Auto-Registration Tests")
    @MainActor
    struct AutoRegistrationTests {
        @Test("UserPromptSubmit auto-registers unknown session in busy state")
        func userPromptAutoRegisters() {
            let store = SessionStore()
            #expect(store.sessionCount == 0)

            // Simulate receiving UserPromptSubmit before SessionStart
            store.setBusy(id: "auto-session", workingDirectory: "/auto/path")

            #expect(store.sessionCount == 1)
            #expect(store.sessions.first?.id == "auto-session")
            #expect(store.sessions.first?.state == .working)
            #expect(store.sessions.first?.workingDirectory == "/auto/path")
        }

        @Test("PostToolUse auto-registers unknown session in busy state")
        func postToolUseAutoRegisters() {
            let store = SessionStore()
            #expect(store.sessionCount == 0)

            // Simulate receiving PostToolUse before SessionStart
            store.setBusy(id: "tool-session", workingDirectory: "/tool/path")

            #expect(store.sessionCount == 1)
            #expect(store.sessions.first?.state == .working)
        }

        @Test("Notification auto-registers unknown session in idle state")
        func notificationAutoRegisters() {
            let store = SessionStore()
            #expect(store.sessionCount == 0)

            // Simulate receiving Notification before SessionStart
            store.setIdle(id: "notify-session", workingDirectory: "/notify/path")

            #expect(store.sessionCount == 1)
            #expect(store.sessions.first?.state == .waiting)
            #expect(store.sessions.first?.lastIdleAt != nil)
        }

        @Test("auto-registered session gets working directory")
        func autoRegisteredGetsWorkingDirectory() {
            let store = SessionStore()

            store.setBusy(id: "auto-dir-session", workingDirectory: "/specific/path")

            #expect(store.sessions.first?.workingDirectory == "/specific/path")
        }

        @Test("auto-registered session with nil working directory gets empty string")
        func autoRegisteredNilWorkingDirectory() {
            let store = SessionStore()

            store.setBusy(id: "nil-dir-session", workingDirectory: nil)

            #expect(store.sessions.first?.workingDirectory == "")
        }
    }

    // MARK: - Multiple Sessions Tests

    @Suite("Multiple Sessions Tests")
    @MainActor
    struct MultipleSessionsTests {
        @Test("multiple sessions maintain independent states")
        func independentSessionStates() {
            let store = SessionStore()

            store.registerSession(id: "session-a", workingDirectory: "/path-a")
            store.registerSession(id: "session-b", workingDirectory: "/path-b")
            store.registerSession(id: "session-c", workingDirectory: "/path-c")

            // Set different states
            store.setBusy(id: "session-a")
            // session-b stays idle
            store.setBusy(id: "session-c")
            store.setIdle(id: "session-c")

            let sessionA = store.sessions.first { $0.id == "session-a" }
            let sessionB = store.sessions.first { $0.id == "session-b" }
            let sessionC = store.sessions.first { $0.id == "session-c" }

            #expect(sessionA?.state == .working)
            #expect(sessionB?.state == .waiting)
            #expect(sessionC?.state == .waiting)
        }

        @Test("interleaved events for multiple sessions")
        func interleavedEvents() {
            let store = SessionStore()

            // Start sessions
            store.registerSession(id: "interleave-1", workingDirectory: "/p1")
            store.registerSession(id: "interleave-2", workingDirectory: "/p2")

            // Interleaved events
            store.setBusy(id: "interleave-1")
            store.setBusy(id: "interleave-2")
            store.setIdle(id: "interleave-1")
            store.setBusy(id: "interleave-1")
            store.setIdle(id: "interleave-2")
            store.setIdle(id: "interleave-1")

            let session1 = store.sessions.first { $0.id == "interleave-1" }
            let session2 = store.sessions.first { $0.id == "interleave-2" }

            #expect(session1?.state == .waiting)
            #expect(session2?.state == .waiting)
        }

        @Test("removing one session does not affect others")
        func removeOneSessionPreservesOthers() {
            let store = SessionStore()

            store.registerSession(id: "keep-1", workingDirectory: "/k1")
            store.registerSession(id: "remove-me", workingDirectory: "/rm")
            store.registerSession(id: "keep-2", workingDirectory: "/k2")

            store.setBusy(id: "keep-1")
            store.setBusy(id: "remove-me")

            store.removeSession(id: "remove-me")

            #expect(store.sessionCount == 2)
            #expect(store.sessions.contains { $0.id == "keep-1" })
            #expect(store.sessions.contains { $0.id == "keep-2" })
            #expect(!store.sessions.contains { $0.id == "remove-me" })

            // Preserved session still has correct state
            let kept = store.sessions.first { $0.id == "keep-1" }
            #expect(kept?.state == .working)
        }
    }

    // MARK: - Working Directory Updates

    @Suite("Working Directory Updates")
    @MainActor
    struct WorkingDirectoryUpdateTests {
        @Test("setBusy can update working directory")
        func setBusyUpdatesWorkingDirectory() {
            let store = SessionStore()
            store.registerSession(id: "wd-session", workingDirectory: "/original")

            store.setBusy(id: "wd-session", workingDirectory: "/updated")

            #expect(store.sessions.first?.workingDirectory == "/updated")
        }

        @Test("setIdle can update working directory")
        func setIdleUpdatesWorkingDirectory() {
            let store = SessionStore()
            store.registerSession(id: "wd-session", workingDirectory: "/original")
            store.setBusy(id: "wd-session")

            store.setIdle(id: "wd-session", workingDirectory: "/updated")

            #expect(store.sessions.first?.workingDirectory == "/updated")
        }

        @Test("nil working directory preserves existing value")
        func nilWorkingDirectoryPreservesExisting() {
            let store = SessionStore()
            store.registerSession(id: "wd-session", workingDirectory: "/original")

            store.setBusy(id: "wd-session", workingDirectory: nil)

            #expect(store.sessions.first?.workingDirectory == "/original")
        }
    }

    // MARK: - lastIdleAt Timestamp Tests

    @Suite("lastIdleAt Timestamp Tests")
    @MainActor
    struct LastIdleAtTests {
        @Test("newly registered session has lastIdleAt set")
        func newSessionHasLastIdleAt() throws {
            let store = SessionStore()
            let beforeRegister = Date()

            store.registerSession(id: "ts-session", workingDirectory: "/path")

            let lastIdleAt = try #require(store.sessions.first?.lastIdleAt)
            #expect(lastIdleAt >= beforeRegister)
        }

        @Test("setBusy clears lastIdleAt")
        func setBusyClearsLastIdleAt() {
            let store = SessionStore()
            store.registerSession(id: "ts-session", workingDirectory: "/path")
            #expect(store.sessions.first?.lastIdleAt != nil)

            store.setBusy(id: "ts-session")

            #expect(store.sessions.first?.lastIdleAt == nil)
        }

        @Test("setIdle sets new lastIdleAt timestamp")
        func setIdleSetsLastIdleAt() async throws {
            let store = SessionStore()
            store.registerSession(id: "ts-session", workingDirectory: "/path")
            store.setBusy(id: "ts-session")
            #expect(store.sessions.first?.lastIdleAt == nil)

            let beforeIdle = Date()
            try await Task.sleep(for: .milliseconds(10))
            store.setIdle(id: "ts-session")

            let lastIdleAt = try #require(store.sessions.first?.lastIdleAt)
            #expect(lastIdleAt >= beforeIdle)
        }

        @Test("multiple setIdle calls update timestamp")
        func multipleSetIdleUpdatesTimestamp() async throws {
            let store = SessionStore()
            store.registerSession(id: "ts-session", workingDirectory: "/path")

            store.setIdle(id: "ts-session")
            let firstIdleAt = try #require(store.sessions.first?.lastIdleAt)

            try await Task.sleep(for: .milliseconds(50))

            store.setBusy(id: "ts-session")
            store.setIdle(id: "ts-session")
            let secondIdleAt = try #require(store.sessions.first?.lastIdleAt)

            #expect(secondIdleAt > firstIdleAt)
        }
    }

    // MARK: - HTTP Server Integration Tests

    @Suite("HTTP Server Event Integration", .serialized)
    struct HTTPServerEventIntegration {
        @Test("POST /event handles SessionStart correctly")
        func postSessionStart() async throws {
            let store = await SessionStore()
            try await withApp(store: store) { app in
                let payload = HookEvent(
                    sessionId: "http-session-1",
                    eventType: .sessionStart,
                    workingDirectory: "/http/project",
                    timestamp: nil,
                    pid: nil
                )

                try await app.testing().test(.POST, "event", beforeRequest: { req in
                    try req.content.encode(payload)
                }) { response in
                    #expect(response.status == .ok)
                }

                let sessions = await store.sessions
                #expect(sessions.count == 1)
                #expect(sessions.first?.state == .waiting)
            }
        }

        @Test("POST /event handles Notification correctly")
        func postNotification() async throws {
            let store = await SessionStore()
            await store.registerSession(id: "http-session-2", workingDirectory: "/path")
            await store.setBusy(id: "http-session-2")

            try await withApp(store: store) { app in
                let payload = HookEvent(
                    sessionId: "http-session-2",
                    eventType: .notification,
                    workingDirectory: nil,
                    timestamp: nil,
                    pid: nil
                )

                try await app.testing().test(.POST, "event", beforeRequest: { req in
                    try req.content.encode(payload)
                }) { response in
                    #expect(response.status == .ok)
                }

                let sessions = await store.sessions
                #expect(sessions.first?.state == .waiting)
            }
        }

        @Test("POST /event handles UserPromptSubmit correctly")
        func postUserPromptSubmit() async throws {
            let store = await SessionStore()
            await store.registerSession(id: "http-session-3", workingDirectory: "/path")

            try await withApp(store: store) { app in
                let payload = HookEvent(
                    sessionId: "http-session-3",
                    eventType: .userPromptSubmit,
                    workingDirectory: nil,
                    timestamp: nil,
                    pid: nil
                )

                try await app.testing().test(.POST, "event", beforeRequest: { req in
                    try req.content.encode(payload)
                }) { response in
                    #expect(response.status == .ok)
                }

                let sessions = await store.sessions
                #expect(sessions.first?.state == .working)
            }
        }

        @Test("POST /event handles PostToolUse correctly")
        func postPostToolUse() async throws {
            let store = await SessionStore()
            await store.registerSession(id: "http-session-4", workingDirectory: "/path")
            await store.setIdle(id: "http-session-4")

            try await withApp(store: store) { app in
                let payload = HookEvent(
                    sessionId: "http-session-4",
                    eventType: .postToolUse,
                    workingDirectory: nil,
                    timestamp: nil,
                    pid: nil
                )

                try await app.testing().test(.POST, "event", beforeRequest: { req in
                    try req.content.encode(payload)
                }) { response in
                    #expect(response.status == .ok)
                }

                let sessions = await store.sessions
                #expect(sessions.first?.state == .working)
            }
        }

        @Test("POST /event handles SessionEnd correctly")
        func postSessionEnd() async throws {
            let store = await SessionStore()
            await store.registerSession(id: "http-session-5", workingDirectory: "/path")
            let countBefore = await store.sessionCount
            #expect(countBefore == 1)

            try await withApp(store: store) { app in
                let payload = HookEvent(
                    sessionId: "http-session-5",
                    eventType: .sessionEnd,
                    workingDirectory: nil,
                    timestamp: nil,
                    pid: nil
                )

                try await app.testing().test(.POST, "event", beforeRequest: { req in
                    try req.content.encode(payload)
                }) { response in
                    #expect(response.status == .ok)
                }

                let count = await store.sessionCount
                #expect(count == 0)
            }
        }

        @Test("full lifecycle via HTTP events")
        func fullLifecycleViaHTTP() async throws {
            let store = await SessionStore()

            try await withApp(store: store) { app in
                // 1. SessionStart
                try await app.testing().test(.POST, "event", beforeRequest: { req in
                    try req.content.encode(HookEvent(
                        sessionId: "lifecycle-http",
                        eventType: .sessionStart,
                        workingDirectory: "/project",
                        timestamp: nil,
                    pid: nil
                    ))
                }) { response in
                    #expect(response.status == .ok)
                }

                var sessions = await store.sessions
                #expect(sessions.first?.state == .waiting)

                // 2. UserPromptSubmit
                try await app.testing().test(.POST, "event", beforeRequest: { req in
                    try req.content.encode(HookEvent(
                        sessionId: "lifecycle-http",
                        eventType: .userPromptSubmit,
                        workingDirectory: nil,
                        timestamp: nil,
                    pid: nil
                    ))
                }) { _ in }

                sessions = await store.sessions
                #expect(sessions.first?.state == .working)

                // 3. PostToolUse (stays busy)
                try await app.testing().test(.POST, "event", beforeRequest: { req in
                    try req.content.encode(HookEvent(
                        sessionId: "lifecycle-http",
                        eventType: .postToolUse,
                        workingDirectory: nil,
                        timestamp: nil,
                    pid: nil
                    ))
                }) { _ in }

                sessions = await store.sessions
                #expect(sessions.first?.state == .working)

                // 4. Notification (becomes idle)
                try await app.testing().test(.POST, "event", beforeRequest: { req in
                    try req.content.encode(HookEvent(
                        sessionId: "lifecycle-http",
                        eventType: .notification,
                        workingDirectory: nil,
                        timestamp: nil,
                    pid: nil
                    ))
                }) { _ in }

                sessions = await store.sessions
                #expect(sessions.first?.state == .waiting)

                // 5. SessionEnd
                try await app.testing().test(.POST, "event", beforeRequest: { req in
                    try req.content.encode(HookEvent(
                        sessionId: "lifecycle-http",
                        eventType: .sessionEnd,
                        workingDirectory: nil,
                        timestamp: nil,
                    pid: nil
                    ))
                }) { _ in }

                let count = await store.sessionCount
                #expect(count == 0)
            }
        }

        @Test("health endpoint reflects correct states")
        func healthEndpointReflectsStates() async throws {
            let store = await SessionStore()
            await store.registerSession(id: "health-1", workingDirectory: "/p1")
            await store.registerSession(id: "health-2", workingDirectory: "/p2")
            await store.setBusy(id: "health-1")

            try await withApp(store: store) { app in
                try await app.testing().test(.GET, "health") { response in
                    #expect(response.status == .ok)
                    let health = try response.content.decode(HealthResponse.self)

                    #expect(health.activeSessionCount == 2)
                    #expect(health.sessions.count == 2)

                    let busySession = health.sessions.first { $0.state == "busy" }
                    let idleSession = health.sessions.first { $0.state == "idle" }

                    #expect(busySession != nil)
                    #expect(idleSession != nil)
                }
            }
        }

        @Test("POST /event returns 400 for unknown event type")
        func postUnknownEventType() async throws {
            let store = await SessionStore()

            try await withApp(store: store) { app in
                // Send raw JSON with unknown event type (bypasses HookEvent encoding)
                let jsonPayload = """
                {"session_id": "test-session", "event_type": "UnknownEvent", "working_directory": "/path"}
                """

                try await app.testing().test(.POST, "event", beforeRequest: { req in
                    req.headers.contentType = .json
                    req.body = ByteBuffer(string: jsonPayload)
                }) { response in
                    #expect(response.status == .badRequest)
                    let error = try response.content.decode(ErrorResponse.self)
                    #expect(error.error == "Invalid JSON")
                }

                // Verify no session was created
                let count = await store.sessionCount
                #expect(count == 0)
            }
        }

        @Test("POST /event handles empty session ID via HTTP")
        func postEmptySessionId() async throws {
            let store = await SessionStore()

            try await withApp(store: store) { app in
                let payload = HookEvent(
                    sessionId: "",
                    eventType: .sessionStart,
                    workingDirectory: "/path",
                    timestamp: nil,
                    pid: nil
                )

                try await app.testing().test(.POST, "event", beforeRequest: { req in
                    try req.content.encode(payload)
                }) { response in
                    #expect(response.status == .ok)
                }

                // Verify session was created with empty ID
                let sessions = await store.sessions
                #expect(sessions.count == 1)
                #expect(sessions.first?.id == "")
            }
        }

        private func withApp(
            store: SessionStore,
            _ test: @Sendable (Application) async throws -> Void
        ) async throws {
            let app = try await Application.make(.testing)

            HTTPServer.configureRoutes(app: app, store: store)

            do {
                try await test(app)
            } catch {
                try await app.asyncShutdown()
                throw error
            }

            try await app.asyncShutdown()
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    @MainActor
    struct EdgeCases {
        @Test("SessionEnd for non-existent session is no-op")
        func sessionEndNonExistent() {
            let store = SessionStore()
            store.registerSession(id: "existing", workingDirectory: "/path")

            store.removeSession(id: "non-existent")

            #expect(store.sessionCount == 1)
            #expect(store.sessions.first?.id == "existing")
        }

        @Test("duplicate SessionStart is ignored")
        func duplicateSessionStartIgnored() {
            let store = SessionStore()

            store.registerSession(id: "dup-session", workingDirectory: "/first")
            store.registerSession(id: "dup-session", workingDirectory: "/second")

            #expect(store.sessionCount == 1)
            #expect(store.sessions.first?.workingDirectory == "/first")
        }

        @Test("setBusy on already busy session updates state correctly")
        func setBusyOnBusySession() {
            let store = SessionStore()
            store.registerSession(id: "busy-session", workingDirectory: "/path")

            store.setBusy(id: "busy-session")
            store.setBusy(id: "busy-session")

            #expect(store.sessions.first?.state == .working)
            #expect(store.sessions.first?.lastIdleAt == nil)
        }

        @Test("setIdle on already idle session updates timestamp")
        func setIdleOnIdleSession() async throws {
            let store = SessionStore()
            store.registerSession(id: "idle-session", workingDirectory: "/path")

            let firstIdleAt = try #require(store.sessions.first?.lastIdleAt)
            try await Task.sleep(for: .milliseconds(50))
            store.setIdle(id: "idle-session")
            let secondIdleAt = try #require(store.sessions.first?.lastIdleAt)

            #expect(store.sessions.first?.state == .waiting)
            #expect(secondIdleAt > firstIdleAt)
        }

        @Test("empty session ID is handled")
        func emptySessionIdHandled() {
            let store = SessionStore()

            store.registerSession(id: "", workingDirectory: "/path")

            #expect(store.sessionCount == 1)
            #expect(store.sessions.first?.id == "")
        }

        @Test("special characters in session ID")
        func specialCharsInSessionId() {
            let store = SessionStore()
            let specialId = "session-with-special/chars:and@symbols!"

            store.registerSession(id: specialId, workingDirectory: "/path")
            store.setBusy(id: specialId)
            store.setIdle(id: specialId)

            #expect(store.sessionCount == 1)
            #expect(store.sessions.first?.id == specialId)
        }

        @Test("unicode in working directory")
        func unicodeInWorkingDirectory() {
            let store = SessionStore()
            let unicodePath = "/Users/test/projet-de-caf\u{00E9}/\u{1F4BB}"

            store.registerSession(id: "unicode-session", workingDirectory: unicodePath)

            #expect(store.sessions.first?.workingDirectory == unicodePath)
        }
    }
}
