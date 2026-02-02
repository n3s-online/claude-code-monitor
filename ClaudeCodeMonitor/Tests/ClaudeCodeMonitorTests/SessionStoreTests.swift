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

    // MARK: - PID Tracking Tests

    @Test("registerSession stores PID")
    func registerSessionWithPid() {
        let store = SessionStore()
        store.registerSession(id: "test-123", workingDirectory: "/test/path", pid: 12345)

        #expect(store.sessions.first?.pid == 12345)
        #expect(store.sessions.first?.isTracked == true)
    }

    @Test("registerSession without PID creates untracked session")
    func registerSessionWithoutPid() {
        let store = SessionStore()
        store.registerSession(id: "test-123", workingDirectory: "/test/path")

        #expect(store.sessions.first?.pid == nil)
        #expect(store.sessions.first?.isTracked == false)
    }

    @Test("registerSession does not overwrite existing PID")
    func registerSessionPreservesPid() {
        let store = SessionStore()
        store.registerSession(id: "test-123", workingDirectory: "/test/path", pid: 12345)
        store.registerSession(id: "test-123", workingDirectory: "/different/path", pid: 99999)

        #expect(store.sessions.first?.pid == 12345)  // Original PID preserved
    }

    @Test("registerSession can upgrade untracked session to tracked")
    func registerSessionUpgradesPid() {
        let store = SessionStore()
        store.registerSession(id: "test-123", workingDirectory: "/test/path", pid: nil)
        #expect(store.sessions.first?.pid == nil)

        store.registerSession(id: "test-123", workingDirectory: "/test/path", pid: 12345)
        #expect(store.sessions.first?.pid == 12345)
    }

    @Test("setBusy stores PID")
    func setBusyWithPid() {
        let store = SessionStore()
        store.setBusy(id: "test-123", workingDirectory: "/test/path", pid: 12345)

        #expect(store.sessions.first?.pid == 12345)
    }

    @Test("setBusy preserves existing PID")
    func setBusyPreservesPid() {
        let store = SessionStore()
        store.registerSession(id: "test-123", workingDirectory: "/test/path", pid: 12345)
        store.setBusy(id: "test-123", workingDirectory: "/test/path", pid: 99999)

        #expect(store.sessions.first?.pid == 12345)  // Original preserved
    }

    @Test("setIdle stores PID")
    func setIdleWithPid() {
        let store = SessionStore()
        store.setIdle(id: "test-123", workingDirectory: "/test/path", pid: 12345)

        #expect(store.sessions.first?.pid == 12345)
    }

    @Test("setIdle preserves existing PID")
    func setIdlePreservesPid() {
        let store = SessionStore()
        store.registerSession(id: "test-123", workingDirectory: "/test/path", pid: 12345)
        store.setIdle(id: "test-123", workingDirectory: "/test/path", pid: 99999)

        #expect(store.sessions.first?.pid == 12345)  // Original preserved
    }

    // MARK: - Process Cleanup Tests

    @Test("isProcessAlive returns true for current process")
    func isProcessAliveForCurrentProcess() {
        let store = SessionStore()
        let currentPid = getpid()

        #expect(store.isProcessAlive(currentPid) == true)
    }

    @Test("isProcessAlive returns false for non-existent process")
    func isProcessAliveForDeadProcess() {
        let store = SessionStore()
        // PID 99999999 is unlikely to exist
        let deadPid: Int32 = 99999999

        #expect(store.isProcessAlive(deadPid) == false)
    }

    @Test("cleanupDeadProcesses removes sessions with dead PIDs")
    func cleanupRemovesDeadProcessSessions() {
        let store = SessionStore()
        // Use a PID that definitely doesn't exist
        let deadPid: Int32 = 99999999
        store.registerSession(id: "dead-session", workingDirectory: "/test/path", pid: deadPid)

        #expect(store.sessionCount == 1)

        store.cleanupDeadProcesses()

        #expect(store.sessionCount == 0)
    }

    @Test("cleanupDeadProcesses preserves sessions with live PIDs")
    func cleanupPreservesLiveProcessSessions() {
        let store = SessionStore()
        let currentPid = getpid()
        store.registerSession(id: "live-session", workingDirectory: "/test/path", pid: currentPid)

        #expect(store.sessionCount == 1)

        store.cleanupDeadProcesses()

        #expect(store.sessionCount == 1)
        #expect(store.sessions.first?.id == "live-session")
    }

    @Test("cleanupDeadProcesses preserves untracked sessions")
    func cleanupPreservesUntrackedSessions() {
        let store = SessionStore()
        store.registerSession(id: "untracked-session", workingDirectory: "/test/path", pid: nil)

        #expect(store.sessionCount == 1)
        #expect(store.sessions.first?.isTracked == false)

        store.cleanupDeadProcesses()

        #expect(store.sessionCount == 1)
        #expect(store.sessions.first?.id == "untracked-session")
    }

    @Test("cleanupDeadProcesses handles mixed session types")
    func cleanupHandlesMixedSessions() {
        let store = SessionStore()
        let currentPid = getpid()
        let deadPid: Int32 = 99999999

        store.registerSession(id: "live-session", workingDirectory: "/path1", pid: currentPid)
        store.registerSession(id: "dead-session", workingDirectory: "/path2", pid: deadPid)
        store.registerSession(id: "untracked-session", workingDirectory: "/path3", pid: nil)

        #expect(store.sessionCount == 3)

        store.cleanupDeadProcesses()

        #expect(store.sessionCount == 2)
        #expect(store.sessions.contains { $0.id == "live-session" })
        #expect(!store.sessions.contains { $0.id == "dead-session" })
        #expect(store.sessions.contains { $0.id == "untracked-session" })
    }
}
