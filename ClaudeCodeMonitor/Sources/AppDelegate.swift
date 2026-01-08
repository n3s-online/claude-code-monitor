import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupOverlayWindow()
    }

    private func setupOverlayWindow() {
        let screenFrame = NSScreen.main?.frame ?? .zero
        let windowWidth: CGFloat = 300
        let windowHeight: CGFloat = 200
        let origin = CGPoint(x: 20, y: screenFrame.height - windowHeight - 50)

        overlayWindow = NSWindow(
            contentRect: NSRect(origin: origin, size: CGSize(width: windowWidth, height: windowHeight)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        overlayWindow.level = .screenSaver
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlayWindow.isOpaque = false
        overlayWindow.backgroundColor = .clear
        overlayWindow.ignoresMouseEvents = true
        overlayWindow.alphaValue = 0.3
        overlayWindow.hasShadow = false

        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12

        overlayWindow.contentView = visualEffectView
        overlayWindow.orderFront(nil)
    }
}
