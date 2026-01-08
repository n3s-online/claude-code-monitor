import Testing
import Foundation
@testable import ClaudeCodeMonitor

@Suite("SessionStore Tests")
@MainActor
struct SessionStoreTests {
    @Test("addSession increases count")
    func addSessionIncreasesCount() {
        let store = SessionStore()
        #expect(store.sessionCount == 0)

        let session = Session(
            id: "test-123",
            workingDirectory: "/test/path",
            startedAt: Date()
        )
        store.addSession(session)

        #expect(store.sessionCount == 1)
        #expect(store.sessions.first?.id == "test-123")
    }

    @Test("removeSession decreases count")
    func removeSessionDecreasesCount() {
        let store = SessionStore()
        let session = Session(
            id: "test-123",
            workingDirectory: "/test/path",
            startedAt: Date()
        )
        store.addSession(session)
        #expect(store.sessionCount == 1)

        store.removeSession(id: "test-123")
        #expect(store.sessionCount == 0)
    }

    @Test("duplicate session is ignored")
    func duplicateSessionIgnored() {
        let store = SessionStore()
        let session1 = Session(
            id: "test-123",
            workingDirectory: "/test/path",
            startedAt: Date()
        )
        let session2 = Session(
            id: "test-123",
            workingDirectory: "/different/path",
            startedAt: Date()
        )

        store.addSession(session1)
        store.addSession(session2)

        #expect(store.sessionCount == 1)
        #expect(store.sessions.first?.workingDirectory == "/test/path")
    }

    @Test("removeSession with invalid id is no-op")
    func removeInvalidIdIsNoOp() {
        let store = SessionStore()
        let session = Session(
            id: "test-123",
            workingDirectory: "/test/path",
            startedAt: Date()
        )
        store.addSession(session)

        store.removeSession(id: "nonexistent")

        #expect(store.sessionCount == 1)
    }

    @Test("multiple sessions can be managed")
    func multipleSessionsManaged() {
        let store = SessionStore()
        let session1 = Session(id: "session-1", workingDirectory: "/path1", startedAt: Date())
        let session2 = Session(id: "session-2", workingDirectory: "/path2", startedAt: Date())
        let session3 = Session(id: "session-3", workingDirectory: "/path3", startedAt: Date())

        store.addSession(session1)
        store.addSession(session2)
        store.addSession(session3)

        #expect(store.sessionCount == 3)

        store.removeSession(id: "session-2")

        #expect(store.sessionCount == 2)
        #expect(store.sessions.contains { $0.id == "session-1" })
        #expect(!store.sessions.contains { $0.id == "session-2" })
        #expect(store.sessions.contains { $0.id == "session-3" })
    }
}
