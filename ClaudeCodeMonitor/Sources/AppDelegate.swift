import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: NSWindow!
    let sessionStore = SessionStore()
    var processMonitor: ProcessMonitor?
    var httpServer: HTTPServer?
    var globalEventMonitor: Any?
    var localEventMonitor: Any?
    var signalSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupOverlayWindow()
        setupEventMonitor()
        startProcessMonitor()
        startHTTPServer()
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
            await processMonitor?.stop()
            await httpServer?.stop()
            await MainActor.run {
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }
        return .terminateLater
    }

    private func startProcessMonitor() {
        processMonitor = ProcessMonitor(sessionStore: sessionStore)
        Task {
            await processMonitor?.start()
            print("Process monitor started")
        }
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
        visualEffectView.layer?.cornerRadius = 8

        let overlayView = OverlayView(sessionStore: sessionStore)
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        ])

        overlayWindow.contentView = visualEffectView
        overlayWindow.orderFront(nil)
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
