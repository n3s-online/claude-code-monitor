import Testing
import Foundation
import Vapor
import VaporTesting
@testable import ClaudeCodeMonitor

// Tests run serially to avoid port conflicts between concurrent server instances
@Suite("HTTPServer Tests", .serialized)
struct HTTPServerTests {
    @Test("server starts and responds to health check")
    func healthCheck() async throws {
        let store = await SessionStore()
        try await withApp(store: store) { app in
            try await app.testing().test(.GET, "health") { response in
                #expect(response.status == .ok)
                let health = try response.content.decode(HealthResponse.self)
                #expect(health.status == "healthy")
                #expect(health.activeSessionCount == 0)
            }
        }
    }

    @Test("POST /event adds session on SessionStart")
    func addSession() async throws {
        let store = await SessionStore()
        try await withApp(store: store) { app in
            let payload = HookEvent(
                sessionId: "test-session-123",
                eventType: .sessionStart,
                workingDirectory: "/tmp/test",
                timestamp: nil
            )

            try await app.testing().test(.POST, "event", beforeRequest: { req in
                try req.content.encode(payload)
            }) { response in
                #expect(response.status == .ok)
                let result = try response.content.decode(EventResponse.self)
                #expect(result.status == "ok")
            }

            let count = await store.sessionCount
            let sessions = await store.sessions
            #expect(count == 1)
            #expect(sessions.first?.id == "test-session-123")
            #expect(sessions.first?.workingDirectory == "/tmp/test")
        }
    }

    @Test("POST /event removes session on Stop")
    func removeSession() async throws {
        let store = await SessionStore()
        let session = Session(id: "test-remove", workingDirectory: "/tmp", startedAt: Date())
        await store.addSession(session)
        let initialCount = await store.sessionCount
        #expect(initialCount == 1)

        try await withApp(store: store) { app in
            let payload = HookEvent(
                sessionId: "test-remove",
                eventType: .stop,
                workingDirectory: nil,
                timestamp: nil
            )

            try await app.testing().test(.POST, "event", beforeRequest: { req in
                try req.content.encode(payload)
            }) { response in
                #expect(response.status == .ok)
            }

            let count = await store.sessionCount
            #expect(count == 0)
        }
    }

    @Test("POST /event returns 400 for malformed JSON")
    func malformedJson() async throws {
        let store = await SessionStore()
        try await withApp(store: store) { app in
            try await app.testing().test(.POST, "event", beforeRequest: { req in
                req.body = ByteBuffer(string: "not valid json")
                req.headers.contentType = .json
            }) { response in
                #expect(response.status == .badRequest)
                let error = try response.content.decode(ErrorResponse.self)
                #expect(error.error == "Invalid JSON")
            }
        }
    }

    @Test("health check reflects session count")
    func healthCheckWithSessions() async throws {
        let store = await SessionStore()
        await store.addSession(Session(id: "s1", workingDirectory: "/a", startedAt: Date()))
        await store.addSession(Session(id: "s2", workingDirectory: "/b", startedAt: Date()))

        try await withApp(store: store) { app in
            try await app.testing().test(.GET, "health") { response in
                #expect(response.status == .ok)
                let health = try response.content.decode(HealthResponse.self)
                #expect(health.activeSessionCount == 2)
            }
        }
    }

    private func withApp(store: SessionStore, _ test: @Sendable (Application) async throws -> Void) async throws {
        let app = try await Application.make(.testing)

        HTTPServer.configureRoutes(app: app, store: store)

        do {
            try await test(app)
        } catch {
            try await app.asyncShutdown()
            throw error
        }

        try await app.asyncShutdown()
    }
}
