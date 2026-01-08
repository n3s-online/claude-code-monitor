import SwiftUI

struct OverlayView: View {
    @ObservedObject var sessionStore: SessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if sessionStore.sessions.isEmpty {
                EmptyStateView()
            } else {
                ForEach(sessionStore.sessions) { session in
                    SessionRowView(session: session)
                }
            }
        }
    }
}

#if DEBUG
struct OverlayView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OverlayView(sessionStore: SessionStore())
                .previewDisplayName("Empty State")

            OverlayView(sessionStore: makePopulatedStore())
                .previewDisplayName("With Sessions")
        }
        .padding()
    }

    static func makePopulatedStore() -> SessionStore {
        let store = SessionStore()
        store.addSession(
            Session(
                id: "abc123def456",
                workingDirectory: "/Users/demo/Projects/my-app",
                pid: 12345,
                state: .working,
                startedAt: Date()
            )
        )
        store.addSession(
            Session(
                id: "xyz789ghi012",
                workingDirectory: "/Users/demo/Documents/other-project",
                pid: 67890,
                state: .waiting,
                startedAt: Date()
            )
        )
        return store
    }
}
#endif
