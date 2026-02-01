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
}
