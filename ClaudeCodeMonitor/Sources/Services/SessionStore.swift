import Foundation
import Combine
import os

private let logger = Logger(subsystem: "ClaudeCodeMonitor", category: "SessionStore")

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []

    private var cleanupTask: Task<Void, Never>?
    private let processCheckInterval: TimeInterval = 10  // Check every 10 seconds

    /// Register a new session in idle state
    /// - Parameters:
    ///   - id: Session identifier
    ///   - workingDirectory: Working directory path
    ///   - pid: Process ID (nil = untracked session)
    func registerSession(id: String, workingDirectory: String, pid: Int32? = nil) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            // Session already exists - only update PID if we have one and existing doesn't
            if pid != nil && sessions[index].pid == nil {
                sessions[index] = Session(
                    id: sessions[index].id,
                    workingDirectory: sessions[index].workingDirectory,
                    state: sessions[index].state,
                    startedAt: sessions[index].startedAt,
                    lastIdleAt: sessions[index].lastIdleAt,
                    pid: pid
                )
                let pidStr = pid.map { String($0) } ?? "unknown"
                logger.info("Updated session \(id, privacy: .public) with PID \(pidStr)")
            } else {
                logger.debug("Session \(id, privacy: .public) already registered, ignoring")
            }
            return
        }

        let session = Session(
            id: id,
            workingDirectory: workingDirectory,
            state: .waiting,
            startedAt: Date(),
            lastIdleAt: Date(),
            pid: pid
        )
        sessions.append(session)
        let pidInfo = pid.map { "PID \($0)" } ?? "untracked"
        logger.info("Registered session \(id, privacy: .public) (\(pidInfo))")
    }

    /// Set session to busy state (auto-registers if unknown)
    /// - Parameters:
    ///   - id: Session identifier
    ///   - workingDirectory: Optional working directory update
    ///   - pid: Process ID (nil = don't update/set PID)
    func setBusy(id: String, workingDirectory: String? = nil, pid: Int32? = nil) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            // Preserve existing PID unless we have a new one and existing is nil
            let newPid = (pid != nil && sessions[index].pid == nil) ? pid : sessions[index].pid
            sessions[index] = Session(
                id: sessions[index].id,
                workingDirectory: workingDirectory ?? sessions[index].workingDirectory,
                state: .working,
                startedAt: sessions[index].startedAt,
                lastIdleAt: nil,
                pid: newPid
            )
            logger.info("Session \(id, privacy: .public) set to busy")
        } else {
            // Auto-register unknown session in busy state
            let session = Session(
                id: id,
                workingDirectory: workingDirectory ?? "",
                state: .working,
                startedAt: Date(),
                lastIdleAt: nil,
                pid: pid
            )
            sessions.append(session)
            let pidInfo = pid.map { "PID \($0)" } ?? "untracked"
            logger.info("Auto-registered session \(id, privacy: .public) in busy state (\(pidInfo))")
        }
    }

    /// Set session to idle state (auto-registers if unknown)
    /// - Parameters:
    ///   - id: Session identifier
    ///   - workingDirectory: Optional working directory update
    ///   - pid: Process ID (nil = don't update/set PID)
    func setIdle(id: String, workingDirectory: String? = nil, pid: Int32? = nil) {
        let now = Date()
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            // Preserve existing PID unless we have a new one and existing is nil
            let newPid = (pid != nil && sessions[index].pid == nil) ? pid : sessions[index].pid
            sessions[index] = Session(
                id: sessions[index].id,
                workingDirectory: workingDirectory ?? sessions[index].workingDirectory,
                state: .waiting,
                startedAt: sessions[index].startedAt,
                lastIdleAt: now,
                pid: newPid
            )
            logger.info("Session \(id, privacy: .public) set to idle")
        } else {
            // Auto-register unknown session in idle state
            let session = Session(
                id: id,
                workingDirectory: workingDirectory ?? "",
                state: .waiting,
                startedAt: now,
                lastIdleAt: now,
                pid: pid
            )
            sessions.append(session)
            let pidInfo = pid.map { "PID \($0)" } ?? "untracked"
            logger.info("Auto-registered session \(id, privacy: .public) in idle state (\(pidInfo))")
        }
    }

    /// Remove a session by ID
    func removeSession(id: String) {
        let countBefore = sessions.count
        sessions.removeAll { $0.id == id }
        if sessions.count < countBefore {
            logger.info("Removed session \(id, privacy: .public)")
        } else {
            logger.debug("Session \(id, privacy: .public) not found for removal")
        }
    }

    /// Start the process liveness check task
    func startProcessCleanup() {
        guard cleanupTask == nil else {
            logger.debug("Process cleanup task already running")
            return
        }

        let checkInterval = processCheckInterval
        logger.info("Starting process cleanup task (checking every \(Int(checkInterval))s)")

        cleanupTask = Task { @MainActor [weak self, checkInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(checkInterval))
                guard let self else { return }
                self.cleanupDeadProcesses()
            }
        }
    }

    /// Stop the process liveness check task
    func stopProcessCleanup() {
        cleanupTask?.cancel()
        cleanupTask = nil
        logger.info("Stopped process cleanup task")
    }

    /// Check if a process is alive using POSIX kill(pid, 0)
    /// Returns true if process exists, false if it doesn't
    func isProcessAlive(_ pid: Int32) -> Bool {
        // kill(pid, 0) returns 0 if process exists and we can signal it
        // Returns -1 with ESRCH if process doesn't exist
        // Returns -1 with EPERM if process exists but we can't signal it (still alive)
        let result = kill(pid, 0)
        if result == 0 {
            return true
        }
        // If EPERM, process exists but we can't signal it - it's still alive
        return errno == EPERM
    }

    func cleanupDeadProcesses() {
        let sessionsToRemove = sessions.filter { session in
            guard let pid = session.pid else {
                return false  // Untracked sessions are not subject to process cleanup
            }
            return !isProcessAlive(pid)
        }

        for session in sessionsToRemove {
            let pidStr = session.pid.map { String($0) } ?? "nil"
            logger.info("Removing session \(session.id, privacy: .public) (PID \(pidStr) no longer exists)")
            sessions.removeAll { $0.id == session.id }
        }

        if !sessionsToRemove.isEmpty {
            logger.info("Cleaned up \(sessionsToRemove.count) dead process sessions")
        }
    }

    var sessionCount: Int {
        sessions.count
    }
}
