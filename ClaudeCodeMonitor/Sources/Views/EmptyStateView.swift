import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        Text("No active sessions")
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.secondary)
            .padding()
    }
}

#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyStateView()
            .padding()
    }
}
#endif
