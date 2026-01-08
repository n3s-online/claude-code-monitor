import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [Session] = []

    func addSession(_ session: Session) {
        guard !sessions.contains(where: { $0.id == session.id }) else { return }
        sessions.append(session)
    }

    func removeSession(id: String) {
        sessions.removeAll { $0.id == id }
    }

    func updateSessionState(id: String, state: SessionState) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index] = Session(
            id: sessions[index].id,
            workingDirectory: sessions[index].workingDirectory,
            pid: sessions[index].pid,
            state: state,
            startedAt: sessions[index].startedAt
        )
    }

    func updateSessions(_ newSessions: [Session]) {
        // Preserve startedAt and state for existing sessions (state is managed by hooks)
        var updated: [Session] = []
        for newSession in newSessions {
            if let existing = sessions.first(where: { $0.id == newSession.id }) {
                // Preserve existing state and startedAt, update PID if it was unknown
                let session = Session(
                    id: newSession.id,
                    workingDirectory: newSession.workingDirectory,
                    pid: newSession.pid,
                    state: existing.state,  // Preserve state from hooks
                    startedAt: existing.startedAt
                )
                updated.append(session)
            } else {
                // New session - use default state (.working)
                updated.append(newSession)
            }
        }
        sessions = updated
    }

    var sessionCount: Int {
        sessions.count
    }
}
