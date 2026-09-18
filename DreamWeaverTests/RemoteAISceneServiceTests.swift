import Foundation
import Testing
@testable import DreamWeaver

@Suite("Remote AI scene service")
struct RemoteAISceneServiceTests {
    @MainActor
    @Test("Generation waits past the ordinary session timeout")
    func generationUsesDedicatedTimeout() async throws {
        #expect(RemoteAISceneService.requestTimeout == 600)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DelayedResponseURLProtocol.self]
        configuration.timeoutIntervalForRequest = 0.05
        let session = URLSession(configuration: configuration)
        let client = APIClient(
            baseURL: URL(string: "https://dreamweaver.test")!,
            session: session
        )
        let service = RemoteAISceneService(client: client, requestTimeout: 1)

        do {
            let _: AISceneDTO.GenerateResult = try await service.generate(selectedSources: [])
            Issue.record("Expected the delayed mock response to return HTTP 503")
        } catch {
            #expect(error as? ServiceError == .httpStatus(503, #"{"detail":"delayed"}"#))
        }

        #expect(DelayedResponseURLProtocol.observedTimeout == 1)
    }
}

private final class DelayedResponseURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var capturedTimeout: TimeInterval?

    private var stopped = false

    static var observedTimeout: TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        return capturedTimeout
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.capturedTimeout = request.timeoutInterval
        Self.lock.unlock()

        Thread.sleep(forTimeInterval: 0.1)
        guard !stopped, let url = request.url else { return }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 503,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"detail":"delayed"}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        stopped = true
    }
}
