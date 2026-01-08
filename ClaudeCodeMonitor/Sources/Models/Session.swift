import Foundation

struct Session: Identifiable, Equatable, Sendable {
    let id: String
    let workingDirectory: String
    let startedAt: Date

    var displayId: String {
        String(id.prefix(8)) + "..."
    }

    var displayDirectory: String {
        guard !workingDirectory.isEmpty else { return "" }
        let url = URL(fileURLWithPath: workingDirectory)
        return url.lastPathComponent
    }
}
