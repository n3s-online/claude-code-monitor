import SwiftUI

struct PulsingDotView: View {
    let state: SessionState
    @State private var isPulsing = false

    private static let workingRed = Color(red: 255 / 255, green: 59 / 255, blue: 48 / 255)
    private static let waitingGreen = Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)

    private var dotColor: Color {
        state == .working ? Self.workingRed : Self.waitingGreen
    }

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .animation(
                .easeInOut(duration: state == .working ? 0.4 : 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
            .onChange(of: state) { _, _ in
                // Reset animation when state changes
                isPulsing = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isPulsing = true
                }
            }
    }
}

#if DEBUG
struct PulsingDotView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack {
                PulsingDotView(state: .working)
                Text("Working (Red)")
            }
            HStack {
                PulsingDotView(state: .waiting)
                Text("Waiting (Green)")
            }
        }
        .padding()
    }
}
#endif
