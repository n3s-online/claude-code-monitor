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
            startedAt: Date()
        )
        #expect(session.displayId == "abc12345...")
    }

    @Test("displayId handles short IDs")
    func displayIdShortId() {
        let session = Session(
            id: "abc",
            workingDirectory: "/Users/test/project",
            startedAt: Date()
        )
        #expect(session.displayId == "abc...")
    }

    @Test("displayDirectory extracts folder name")
    func displayDirectoryExtractsFolderName() {
        let session = Session(
            id: "test-id",
            workingDirectory: "/Users/test/my-project",
            startedAt: Date()
        )
        #expect(session.displayDirectory == "my-project")
    }

    @Test("displayDirectory handles trailing slash")
    func displayDirectoryTrailingSlash() {
        let session = Session(
            id: "test-id",
            workingDirectory: "/Users/test/my-project/",
            startedAt: Date()
        )
        #expect(session.displayDirectory == "my-project")
    }

    @Test("displayDirectory handles root path")
    func displayDirectoryRoot() {
        let session = Session(
            id: "test-id",
            workingDirectory: "/",
            startedAt: Date()
        )
        #expect(session.displayDirectory == "/")
    }

    @Test("displayDirectory handles empty string")
    func displayDirectoryEmpty() {
        let session = Session(
            id: "test-id",
            workingDirectory: "",
            startedAt: Date()
        )
        #expect(session.displayDirectory == "")
    }

    @Test("Session equality")
    func sessionEquality() {
        let date = Date()
        let session1 = Session(id: "123", workingDirectory: "/test", startedAt: date)
        let session2 = Session(id: "123", workingDirectory: "/test", startedAt: date)
        let session3 = Session(id: "456", workingDirectory: "/test", startedAt: date)

        #expect(session1 == session2)
        #expect(session1 != session3)
    }
}
