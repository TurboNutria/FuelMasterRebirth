import Foundation
@testable import NetworkLayer
import Testing

/// Serves canned responses in place of the network. A queue of responses per test.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [(status: Int, body: Foundation.Data)] = []
    nonisolated(unsafe) static var error: URLError?
    nonisolated(unsafe) static var requests = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests += 1
        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let next = Self.responses.isEmpty ? (status: 200, body: Foundation.Data()) : Self.responses.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: next.status, httpVersion: nil,
                                       headerFields: ["Content-Type": "text/html"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: next.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func reset() {
        responses = []
        error = nil
        requests = 0
    }
}

struct Sample: Decodable, Sendable, Equatable {
    let value: String
}

@Suite("NetworkService", .serialized)
struct NetworkServiceTests {
    let request = NetworkRequest(url: URL(string: "https://example.test/prices")!)

    @Test func stripsTheByteOrderMarkBeforeDecoding() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.responses = [(200, Foundation.Data([0xEF, 0xBB, 0xBF]) + Foundation.Data(#"{"value":"ok"}"#.utf8))]
        let service = NetworkService(session: StubURLProtocol.session(), retry: .none)
        #expect(try await service.decode(Sample.self, from: request) == Sample(value: "ok"))
    }

    @Test func retriesServerErrorsThenSucceeds() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.responses = [(503, Foundation.Data()), (200, Foundation.Data(#"{"value":"second"}"#.utf8))]
        let service = NetworkService(session: StubURLProtocol.session(), retry: .init(maxAttempts: 3, baseDelay: .milliseconds(1)))
        #expect(try await service.decode(Sample.self, from: request).value == "second")
        #expect(StubURLProtocol.requests == 2)
    }

    @Test func doesNotRetryClientErrors() async {
        StubURLProtocol.reset()
        StubURLProtocol.responses = [(404, Foundation.Data())]
        let service = NetworkService(session: StubURLProtocol.session(), retry: .init(maxAttempts: 3, baseDelay: .milliseconds(1)))
        await #expect(throws: NetworkError.http(status: 404)) { try await service.data(for: request) }
        #expect(StubURLProtocol.requests == 1)
    }

    @Test func mapsNoConnectionToOffline() async {
        StubURLProtocol.reset()
        StubURLProtocol.error = URLError(.notConnectedToInternet)
        let service = NetworkService(session: StubURLProtocol.session(), retry: .none)
        await #expect(throws: NetworkError.offline) { try await service.data(for: request) }
    }

    @Test func reportsUndecodableBodies() async {
        StubURLProtocol.reset()
        StubURLProtocol.responses = [(200, Foundation.Data("<html>".utf8))]
        let service = NetworkService(session: StubURLProtocol.session(), retry: .none)
        await #expect { try await service.decode(Sample.self, from: request) } throws: { error in
            if case .decoding = error as? NetworkError { return true }
            return false
        }
    }
}
