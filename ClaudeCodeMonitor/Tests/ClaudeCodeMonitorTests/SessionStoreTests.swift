import Testing
import Foundation
@testable import ClaudeCodeMonitor

@Suite("SessionStore Tests")
@MainActor
struct SessionStoreTests {
    @Test("registerSession increases count")
    func registerSessionIncreasesCount() {
        let store = SessionStore()
        #expect(store.sessionCount == 0)

        store.registerSession(id: "test-123", workingDirectory: "/test/path")

        #expect(store.sessionCount == 1)
        #expect(store.sessions.first?.id == "test-123")
    }

    @Test("removeSession decreases count")
    func removeSessionDecreasesCount() {
        let store = SessionStore()
        store.registerSession(id: "test-123", workingDirectory: "/test/path")
        #expect(store.sessionCount == 1)

        store.removeSession(id: "test-123")
        #expect(store.sessionCount == 0)
    }

    @Test("duplicate session is ignored")
    func duplicateSessionIgnored() {
        let store = SessionStore()

        store.registerSession(id: "test-123", workingDirectory: "/test/path")
        store.registerSession(id: "test-123", workingDirectory: "/different/path")

        #expect(store.sessionCount == 1)
        #expect(store.sessions.first?.workingDirectory == "/test/path")
    }

    @Test("removeSession with invalid id is no-op")
    func removeInvalidIdIsNoOp() {
        let store = SessionStore()
        store.registerSession(id: "test-123", workingDirectory: "/test/path")

        store.removeSession(id: "nonexistent")

        #expect(store.sessionCount == 1)
    }

    @Test("multiple sessions can be managed")
    func multipleSessionsManaged() {
        let store = SessionStore()

        store.registerSession(id: "session-1", workingDirectory: "/path1")
        store.registerSession(id: "session-2", workingDirectory: "/path2")
        store.registerSession(id: "session-3", workingDirectory: "/path3")

        #expect(store.sessionCount == 3)

        store.removeSession(id: "session-2")

        #expect(store.sessionCount == 2)
        #expect(store.sessions.contains { $0.id == "session-1" })
        #expect(!store.sessions.contains { $0.id == "session-2" })
        #expect(store.sessions.contains { $0.id == "session-3" })
    }

    @Test("setBusy updates session state")
    func setBusyUpdatesState() {
        let store = SessionStore()
        store.registerSession(id: "test-123", workingDirectory: "/test/path")

        store.setBusy(id: "test-123")

        #expect(store.sessions.first?.state == .working)
        #expect(store.sessions.first?.lastIdleAt == nil)
    }

    @Test("setIdle updates session state")
    func setIdleUpdatesState() {
        let store = SessionStore()
        store.registerSession(id: "test-123", workingDirectory: "/test/path")
        store.setBusy(id: "test-123")

        store.setIdle(id: "test-123")

        #expect(store.sessions.first?.state == .waiting)
        #expect(store.sessions.first?.lastIdleAt != nil)
    }

    @Test("setBusy auto-registers unknown session")
    func setBusyAutoRegisters() {
        let store = SessionStore()
        #expect(store.sessionCount == 0)

        store.setBusy(id: "unknown-session", workingDirectory: "/auto/path")

        #expect(store.sessionCount == 1)
        #expect(store.sessions.first?.id == "unknown-session")
        #expect(store.sessions.first?.state == .working)
    }

    @Test("setIdle auto-registers unknown session")
    func setIdleAutoRegisters() {
        let store = SessionStore()
        #expect(store.sessionCount == 0)

        store.setIdle(id: "unknown-session", workingDirectory: "/auto/path")

        #expect(store.sessionCount == 1)
        #expect(store.sessions.first?.id == "unknown-session")
        #expect(store.sessions.first?.state == .waiting)
    }

    @Test("busy to idle resets timeout")
    func busyToIdleResetsTimeout() async throws {
        let store = SessionStore()
        store.registerSession(id: "test-123", workingDirectory: "/test/path")

        // First cycle: busy -> idle
        store.setBusy(id: "test-123")
        store.setIdle(id: "test-123")
        let firstIdleAt = store.sessions.first?.lastIdleAt
        #expect(firstIdleAt != nil)

        // Wait briefly to ensure time passes
        try await Task.sleep(for: .milliseconds(50))

        // Second cycle: busy -> idle
        store.setBusy(id: "test-123")
        store.setIdle(id: "test-123")
        let secondIdleAt = store.sessions.first?.lastIdleAt
        #expect(secondIdleAt != nil)

        // Verify the second lastIdleAt is later than the first
        #expect(secondIdleAt! > firstIdleAt!)
    }

    @Test("idle timeout removes session")
    func idleTimeoutRemovesSession() {
        // Use a very short timeout for testing (1 second)
        let store = SessionStore(idleTimeoutInterval: 1.0)
        store.registerSession(id: "test-123", workingDirectory: "/test/path")
        #expect(store.sessionCount == 1)

        // With a 1-second timeout, newly registered session should not be removed
        store.cleanupIdleSessions()
        #expect(store.sessionCount == 1, "Session should not be removed immediately")

        // Use 0-second timeout to verify cleanup logic removes idle sessions
        let instantTimeoutStore = SessionStore(idleTimeoutInterval: 0)
        instantTimeoutStore.registerSession(id: "test-456", workingDirectory: "/test/path")
        #expect(instantTimeoutStore.sessionCount == 1)

        // With 0-second timeout, any idle session should be cleaned up
        instantTimeoutStore.cleanupIdleSessions()
        #expect(instantTimeoutStore.sessionCount == 0, "Session should be removed with 0-second timeout")
    }

    @Test("busy session is not timed out")
    func busySessionNotTimedOut() {
        // Use a 0-second timeout so any idle session would be immediately cleaned up
        let store = SessionStore(idleTimeoutInterval: 0)
        store.registerSession(id: "test-123", workingDirectory: "/test/path")

        // Set to busy - lastIdleAt becomes nil
        store.setBusy(id: "test-123")
        #expect(store.sessions.first?.lastIdleAt == nil, "Busy session should have nil lastIdleAt")

        // Cleanup should not remove busy sessions even with 0 timeout
        store.cleanupIdleSessions()
        #expect(store.sessionCount == 1, "Busy session should not be removed by cleanup")
    }

    @Test("multiple sequential updates are safe via actor isolation")
    func multipleSequentialUpdatesAreSafe() async {
        // Note: Since SessionStore is @MainActor, all operations are serialized.
        // This test verifies that multiple task groups submitting work to the
        // main actor complete correctly, demonstrating actor isolation safety.
        let store = SessionStore()

        await withTaskGroup(of: Void.self) { group in
            // Register sessions concurrently
            for i in 0..<10 {
                group.addTask { @MainActor in
                    store.registerSession(id: "session-\(i)", workingDirectory: "/path/\(i)")
                }
            }

            // Wait for all registrations to complete
            await group.waitForAll()
        }

        // All sessions should be registered
        #expect(store.sessionCount == 10)

        // Now perform concurrent state changes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @MainActor in
                    store.setBusy(id: "session-\(i)")
                }
            }
            await group.waitForAll()
        }

        // All sessions should be busy
        #expect(store.sessions.allSatisfy { $0.state == .working })

        // Concurrent idle transitions
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @MainActor in
                    store.setIdle(id: "session-\(i)")
                }
            }
            await group.waitForAll()
        }

        // All sessions should be idle
        #expect(store.sessions.allSatisfy { $0.state == .waiting })

        // Concurrent removals
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask { @MainActor in
                    store.removeSession(id: "session-\(i)")
                }
            }
            await group.waitForAll()
        }

        // 5 sessions should remain
        #expect(store.sessionCount == 5)
    }
}
