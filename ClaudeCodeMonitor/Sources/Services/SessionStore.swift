import Foundation
import Combine
import os

private let logger = Logger(subsystem: "ClaudeCodeMonitor", category: "SessionStore")

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []

    private var cleanupTask: Task<Void, Never>?
    private let idleTimeoutInterval: TimeInterval = 4 * 60 * 60  // 4 hours
    private let cleanupCheckInterval: TimeInterval = 60  // 60 seconds

    /// Register a new session in idle state
    func registerSession(id: String, workingDirectory: String) {
        if sessions.contains(where: { $0.id == id }) {
            logger.debug("Session \(id, privacy: .public) already registered, ignoring")
            return
        }

        let session = Session(
            id: id,
            workingDirectory: workingDirectory,
            state: .waiting,
            startedAt: Date(),
            lastIdleAt: Date()
        )
        sessions.append(session)
        logger.info("Registered session \(id, privacy: .public) in idle state")
    }

    /// Set session to busy state (auto-registers if unknown)
    func setBusy(id: String, workingDirectory: String? = nil) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index] = Session(
                id: sessions[index].id,
                workingDirectory: workingDirectory ?? sessions[index].workingDirectory,
                state: .working,
                startedAt: sessions[index].startedAt,
                lastIdleAt: nil
            )
            logger.info("Session \(id, privacy: .public) set to busy")
        } else {
            // Auto-register unknown session in busy state
            let session = Session(
                id: id,
                workingDirectory: workingDirectory ?? "",
                state: .working,
                startedAt: Date(),
                lastIdleAt: nil
            )
            sessions.append(session)
            logger.info("Auto-registered session \(id, privacy: .public) in busy state")
        }
    }

    /// Set session to idle state (auto-registers if unknown)
    func setIdle(id: String, workingDirectory: String? = nil) {
        let now = Date()
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index] = Session(
                id: sessions[index].id,
                workingDirectory: workingDirectory ?? sessions[index].workingDirectory,
                state: .waiting,
                startedAt: sessions[index].startedAt,
                lastIdleAt: now
            )
            logger.info("Session \(id, privacy: .public) set to idle")
        } else {
            // Auto-register unknown session in idle state
            let session = Session(
                id: id,
                workingDirectory: workingDirectory ?? "",
                state: .waiting,
                startedAt: now,
                lastIdleAt: now
            )
            sessions.append(session)
            logger.info("Auto-registered session \(id, privacy: .public) in idle state")
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

    /// Start the idle cleanup task
    func startIdleCleanup() {
        guard cleanupTask == nil else {
            logger.debug("Idle cleanup task already running")
            return
        }

        let checkInterval = cleanupCheckInterval
        let timeoutHours = Int(idleTimeoutInterval / 3600)
        logger.info("Starting idle cleanup task (checking every \(Int(checkInterval))s, timeout: \(timeoutHours)h)")

        cleanupTask = Task { @MainActor [weak self, checkInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(checkInterval))
                guard let self else { return }
                self.cleanupIdleSessions()
            }
        }
    }

    /// Stop the idle cleanup task
    func stopIdleCleanup() {
        cleanupTask?.cancel()
        cleanupTask = nil
        logger.info("Stopped idle cleanup task")
    }

    private func cleanupIdleSessions() {
        let now = Date()
        let sessionsToRemove = sessions.filter { session in
            guard let lastIdleAt = session.lastIdleAt else {
                return false  // Busy sessions are not subject to idle timeout
            }
            return now.timeIntervalSince(lastIdleAt) > idleTimeoutInterval
        }

        for session in sessionsToRemove {
            logger.info("Removing session \(session.id, privacy: .public) due to idle timeout")
            sessions.removeAll { $0.id == session.id }
        }

        if !sessionsToRemove.isEmpty {
            logger.info("Cleaned up \(sessionsToRemove.count) idle sessions")
        }
    }

    var sessionCount: Int {
        sessions.count
    }
}
