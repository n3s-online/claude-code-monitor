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
        store.setBusy(id: "abc123def456", workingDirectory: "/Users/demo/Projects/my-app")
        store.setIdle(id: "xyz789ghi012", workingDirectory: "/Users/demo/Documents/other-project")
        return store
    }
}
#endif
