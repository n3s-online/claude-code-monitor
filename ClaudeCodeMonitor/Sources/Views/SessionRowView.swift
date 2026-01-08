import SwiftUI

struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack(spacing: 8) {
            PulsingDotView()
            Text(session.displayId)
                .font(.system(.body, design: .monospaced))
            Text(session.displayDirectory)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

#if DEBUG
struct SessionRowView_Previews: PreviewProvider {
    static var previews: some View {
        SessionRowView(
            session: Session(
                id: "abc123def456",
                workingDirectory: "/Users/demo/Projects/my-app",
                startedAt: Date()
            )
        )
        .padding()
    }
}
#endif
