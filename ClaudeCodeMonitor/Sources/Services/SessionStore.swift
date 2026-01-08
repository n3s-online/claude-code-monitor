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

    var sessionCount: Int {
        sessions.count
    }
}
