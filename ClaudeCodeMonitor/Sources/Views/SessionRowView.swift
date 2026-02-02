import SwiftUI

struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack(spacing: 8) {
            PulsingDotView(state: session.state)
            Text(session.displayDirectory)
                .font(.system(.body, design: .monospaced))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

#if DEBUG
struct SessionRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SessionRowView(
                session: Session(
                    id: "abc123def456",
                    workingDirectory: "/Users/demo/Projects/my-app",
                    state: .working,
                    startedAt: Date(),
                    lastIdleAt: nil
                )
            )
            SessionRowView(
                session: Session(
                    id: "xyz789ghi012",
                    workingDirectory: "/Users/demo/Projects/other-app",
                    state: .waiting,
                    startedAt: Date(),
                    lastIdleAt: Date()
                )
            )
        }
        .padding()
    }
}
#endif
