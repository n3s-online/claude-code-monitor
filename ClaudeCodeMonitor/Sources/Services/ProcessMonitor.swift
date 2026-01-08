import Foundation

actor ProcessMonitor {
    private let sessionStore: SessionStore
    private var monitorTask: Task<Void, Never>?
    private let pollInterval: TimeInterval = 1.5

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    func start() {
        guard monitorTask == nil else { return }
        monitorTask = Task {
            while !Task.isCancelled {
                await pollProcesses()
                try? await Task.sleep(for: .seconds(pollInterval))
            }
        }
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    private func pollProcesses() async {
        let processes = findClaudeProcesses()
        var currentSessions: [Session] = []

        for process in processes {
            guard let workingDir = getWorkingDirectory(pid: process.pid) else { continue }
            let sessionId = findSessionId(workingDirectory: workingDir) ?? "pid-\(process.pid)"

            // Default to working state for new sessions; existing state preserved by SessionStore
            let session = Session(
                id: sessionId,
                workingDirectory: workingDir,
                pid: process.pid,
                state: .working,
                startedAt: Date()
            )
            currentSessions.append(session)
        }

        await sessionStore.updateSessions(currentSessions)
    }

    private struct ClaudeProcess {
        let pid: Int32
    }

    private func findClaudeProcesses() -> [ClaudeProcess] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "claude"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            return output
                .split(separator: "\n")
                .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
                .map { ClaudeProcess(pid: $0) }
        } catch {
            return []
        }
    }

    private func getWorkingDirectory(pid: Int32) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-p", String(pid), "-Fn"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            // lsof -Fn outputs lines like "fcwd" followed by "n/path/to/dir"
            let lines = output.split(separator: "\n").map(String.init)
            for (index, line) in lines.enumerated() {
                if line == "fcwd", index + 1 < lines.count {
                    let pathLine = lines[index + 1]
                    if pathLine.hasPrefix("n") {
                        return String(pathLine.dropFirst())
                    }
                }
            }
            return nil
        } catch {
            return nil
        }
    }

    private func findSessionId(workingDirectory: String) -> String? {
        let encoded = workingDirectory.replacingOccurrences(of: "/", with: "-")
        let sessionDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects/\(encoded)")

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: sessionDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        // Find most recently modified .jsonl file (excluding agent files)
        let sessionFiles = contents
            .filter { $0.pathExtension == "jsonl" && !$0.lastPathComponent.hasPrefix("agent-") }
            .compactMap { url -> (URL, Date)? in
                guard let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                      let modDate = attrs.contentModificationDate else { return nil }
                return (url, modDate)
            }
            .sorted { $0.1 > $1.1 }

        guard let latestSession = sessionFiles.first else { return nil }
        return latestSession.0.deletingPathExtension().lastPathComponent
    }
}
