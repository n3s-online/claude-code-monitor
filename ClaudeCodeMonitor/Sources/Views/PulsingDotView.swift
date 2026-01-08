import SwiftUI

struct PulsingDotView: View {
    @State private var isPulsing = false

    private static let activeGreen = Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)

    var body: some View {
        Circle()
            .fill(Self.activeGreen)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

#if DEBUG
struct PulsingDotView_Previews: PreviewProvider {
    static var previews: some View {
        PulsingDotView()
            .padding()
    }
}
#endif
