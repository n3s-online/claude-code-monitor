import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: NSWindow!
    let sessionStore = SessionStore()
    var httpServer: HTTPServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupOverlayWindow()
        startServer()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await httpServer?.stop()
            await MainActor.run {
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }
        return .terminateLater
    }

    private func startServer() {
        httpServer = HTTPServer(sessionStore: sessionStore)
        Task {
            do {
                try await httpServer?.start()
                print("HTTP server started on port 7779")
            } catch {
                print("Failed to start HTTP server: \(error)")
            }
        }
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
