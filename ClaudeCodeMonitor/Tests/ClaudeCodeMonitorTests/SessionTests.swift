import Testing
import Foundation
@testable import ClaudeCodeMonitor

@Suite("Session Tests")
struct SessionTests {
    @Test("displayId truncates to 8 chars with ellipsis")
    func displayIdTruncates() {
        let session = Session(
            id: "abc12345678def",
            workingDirectory: "/Users/test/project",
            state: .waiting,
            startedAt: Date(),
            lastIdleAt: Date()
        )
        #expect(session.displayId == "abc12345...")
    }

    @Test("displayId handles short IDs")
    func displayIdShortId() {
        let session = Session(
            id: "abc",
            workingDirectory: "/Users/test/project",
            state: .waiting,
            startedAt: Date(),
            lastIdleAt: Date()
        )
        #expect(session.displayId == "abc...")
    }

    @Test("displayDirectory extracts folder name")
    func displayDirectoryExtractsFolderName() {
        let session = Session(
            id: "test-id",
            workingDirectory: "/Users/test/my-project",
            state: .waiting,
            startedAt: Date(),
            lastIdleAt: Date()
        )
        #expect(session.displayDirectory == "my-project")
    }

    @Test("displayDirectory handles trailing slash")
    func displayDirectoryTrailingSlash() {
        let session = Session(
            id: "test-id",
            workingDirectory: "/Users/test/my-project/",
            state: .waiting,
            startedAt: Date(),
            lastIdleAt: Date()
        )
        #expect(session.displayDirectory == "my-project")
    }

    @Test("displayDirectory handles root path")
    func displayDirectoryRoot() {
        let session = Session(
            id: "test-id",
            workingDirectory: "/",
            state: .waiting,
            startedAt: Date(),
            lastIdleAt: Date()
        )
        #expect(session.displayDirectory == "/")
    }

    @Test("displayDirectory handles empty string")
    func displayDirectoryEmpty() {
        let session = Session(
            id: "test-id",
            workingDirectory: "",
            state: .waiting,
            startedAt: Date(),
            lastIdleAt: Date()
        )
        #expect(session.displayDirectory == "")
    }

    @Test("Session equality")
    func sessionEquality() {
        let date = Date()
        let session1 = Session(id: "123", workingDirectory: "/test", state: .waiting, startedAt: date, lastIdleAt: date)
        let session2 = Session(id: "123", workingDirectory: "/test", state: .waiting, startedAt: date, lastIdleAt: date)
        let session3 = Session(id: "456", workingDirectory: "/test", state: .waiting, startedAt: date, lastIdleAt: date)

        #expect(session1 == session2)
        #expect(session1 != session3)
    }

    @Test("isTracked returns true when PID is set")
    func isTrackedWithPid() {
        let session = Session(
            id: "test-id",
            workingDirectory: "/test",
            state: .waiting,
            startedAt: Date(),
            lastIdleAt: Date(),
            pid: 12345
        )
        #expect(session.isTracked == true)
        #expect(session.pid == 12345)
    }

    @Test("isTracked returns false when PID is nil")
    func isTrackedWithoutPid() {
        let session = Session(
            id: "test-id",
            workingDirectory: "/test",
            state: .waiting,
            startedAt: Date(),
            lastIdleAt: Date(),
            pid: nil
        )
        #expect(session.isTracked == false)
        #expect(session.pid == nil)
    }

    @Test("Session equality includes PID")
    func sessionEqualityWithPid() {
        let date = Date()
        let session1 = Session(id: "123", workingDirectory: "/test", state: .waiting, startedAt: date, lastIdleAt: date, pid: 100)
        let session2 = Session(id: "123", workingDirectory: "/test", state: .waiting, startedAt: date, lastIdleAt: date, pid: 100)
        let session3 = Session(id: "123", workingDirectory: "/test", state: .waiting, startedAt: date, lastIdleAt: date, pid: 200)

        #expect(session1 == session2)
        #expect(session1 != session3)
    }
}
