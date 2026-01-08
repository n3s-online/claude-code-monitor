import Vapor

struct EventResponse: Content {
    let status: String

    static let ok = EventResponse(status: "ok")
}

struct HealthResponse: Content {
    let status: String
    let activeSessionCount: Int

    enum CodingKeys: String, CodingKey {
        case status
        case activeSessionCount = "active_sessions"
    }
}

struct ErrorResponse: Content {
    let error: String
}

final class HTTPServer {
    private let sessionStore: SessionStore
    private let port: Int
    private var app: Application?

    init(sessionStore: SessionStore, port: Int = 7779) {
        self.sessionStore = sessionStore
        self.port = port
    }

    func start() async throws {
        let app = try await Application.make(.development)
        self.app = app

        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = port

        Self.configureRoutes(app: app, store: sessionStore)

        try await app.startup()
    }

    func stop() async {
        if let app = app {
            try? await app.asyncShutdown()
            self.app = nil
        }
    }

    static func configureRoutes(app: Application, store: SessionStore) {
        app.post("event") { req async throws -> Response in
            let event: HookEvent
            do {
                event = try req.content.decode(HookEvent.self)
            } catch {
                let error = ErrorResponse(error: "Invalid JSON")
                let response = Response(status: .badRequest)
                try response.content.encode(error)
                return response
            }

            switch event.eventType {
            case .sessionStart:
                let session = Session(
                    id: event.sessionId,
                    workingDirectory: event.workingDirectory ?? "",
                    startedAt: event.timestamp ?? Date()
                )
                await store.addSession(session)

            case .stop:
                await store.removeSession(id: event.sessionId)
            }

            let response = Response(status: .ok)
            try response.content.encode(EventResponse.ok)
            return response
        }

        app.get("health") { req async throws -> HealthResponse in
            let count = await store.sessionCount
            return HealthResponse(status: "healthy", activeSessionCount: count)
        }
    }
}
