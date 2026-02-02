import AppKit
import Combine
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: NSWindow!
    let sessionStore = SessionStore()
    var httpServer: HTTPServer?
    var globalEventMonitor: Any?
    var localEventMonitor: Any?
    var signalSource: DispatchSourceSignal?
    var hostingView: NSHostingView<OverlayView>?
    var sessionsCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupOverlayWindow()
        setupEventMonitor()
        startHTTPServer()
        sessionStore.startIdleCleanup()
        setupSignalHandler()
    }

    private func setupSignalHandler() {
        signal(SIGINT, SIG_IGN)
        signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signalSource?.setEventHandler { [weak self] in
            print("\nReceived SIGINT, shutting down...")
            self?.signalSource?.cancel()
            NSApp.terminate(nil)
        }
        signalSource?.resume()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }

        // Schedule forced termination after 2 seconds as fallback on a background thread
        // This ensures we exit even if graceful shutdown hangs (main run loop blocked)
        DispatchQueue.global().async {
            Thread.sleep(forTimeInterval: 2.0)
            print("Forced termination after timeout")
            Darwin.exit(0)
        }

        // Attempt graceful cleanup
        Task {
            sessionStore.stopIdleCleanup()
            await httpServer?.stop()
            await MainActor.run {
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }
        return .terminateLater
    }

    private func startHTTPServer() {
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
        let initialWidth: CGFloat = 250
        let initialHeight: CGFloat = 50
        let origin = CGPoint(x: 20, y: screenFrame.height - initialHeight - 50)

        overlayWindow = NSWindow(
            contentRect: NSRect(origin: origin, size: CGSize(width: initialWidth, height: initialHeight)),
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
        visualEffectView.layer?.cornerRadius = 8

        let overlayView = OverlayView(sessionStore: sessionStore)
        hostingView = NSHostingView(rootView: overlayView)
        hostingView!.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(hostingView!)

        NSLayoutConstraint.activate([
            hostingView!.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView!.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView!.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView!.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        ])

        overlayWindow.contentView = visualEffectView
        overlayWindow.orderFront(nil)

        // Observe session changes and resize window accordingly
        sessionsCancellable = sessionStore.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.resizeWindowToFitContent()
            }

        // Initial resize
        resizeWindowToFitContent()
    }

    private func resizeWindowToFitContent() {
        guard let hostingView = hostingView else { return }
        let screenFrame = NSScreen.main?.frame ?? .zero

        // Get the natural size of the SwiftUI content
        let fittingSize = hostingView.fittingSize

        // Apply constraints: min width 150, max width 400, max height 400
        let minWidth: CGFloat = 150
        let maxWidth: CGFloat = 400
        let maxHeight: CGFloat = 400

        let newWidth = min(max(fittingSize.width, minWidth), maxWidth)
        let newHeight = min(fittingSize.height, maxHeight)

        // Keep window anchored at top-left (20px from left, 50px from top)
        let newOrigin = CGPoint(x: 20, y: screenFrame.height - newHeight - 50)

        overlayWindow.setFrame(
            NSRect(origin: newOrigin, size: CGSize(width: newWidth, height: newHeight)),
            display: true,
            animate: false
        )
    }

    private func setupEventMonitor() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let cmdPressed = event.modifierFlags.contains(.command)
        overlayWindow.ignoresMouseEvents = !cmdPressed

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            overlayWindow.animator().alphaValue = cmdPressed ? 0.8 : 0.3
        }
    }
}
