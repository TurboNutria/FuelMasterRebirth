import Foundation

public struct NetworkRequest: Sendable, Hashable {
    public let url: URL
    public var headers: [String: String]
    public var timeout: TimeInterval

    public init(url: URL, headers: [String: String] = ["Accept": "application/json"], timeout: TimeInterval = 30) {
        self.url = url
        self.headers = headers
        self.timeout = timeout
    }
}

public enum NetworkError: Error, Sendable, Equatable {
    /// No connection, or the connection dropped.
    case offline
    case timedOut
    /// The server answered with a non-2xx status.
    case http(status: Int)
    /// The body couldn't be decoded.
    case decoding(String)
    case invalidResponse
}

/// The one network entry point every repository uses.
public protocol NetworkServiceProtocol: Sendable {
    /// Raw body, with a leading UTF-8 byte-order mark removed.
    func data(for request: NetworkRequest) async throws(NetworkError) -> Foundation.Data
    func decode<T: Decodable & Sendable>(_ type: T.Type, from request: NetworkRequest) async throws(NetworkError) -> T
}

/// GET requests with retries for transient failures (timeouts, 5xx), exponential backoff and
/// tolerant body handling: the ministry sends JSON labelled `text/html`, with a BOM in front.
public struct NetworkService: NetworkServiceProtocol {
    public struct RetryPolicy: Sendable {
        public var maxAttempts: Int
        public var baseDelay: Duration

        public init(maxAttempts: Int = 3, baseDelay: Duration = .milliseconds(500)) {
            self.maxAttempts = maxAttempts
            self.baseDelay = baseDelay
        }

        public static let none = RetryPolicy(maxAttempts: 1, baseDelay: .zero)
    }

    private let session: URLSession
    private let retry: RetryPolicy

    public init(session: URLSession = .shared, retry: RetryPolicy = RetryPolicy()) {
        self.session = session
        self.retry = retry
    }

    public func data(for request: NetworkRequest) async throws(NetworkError) -> Foundation.Data {
        var attempt = 1
        while true {
            do {
                return try await perform(request)
            } catch {
                guard attempt < retry.maxAttempts, Self.isTransient(error) else { throw error }
                let delay = retry.baseDelay * Int(pow(2.0, Double(attempt - 1)))
                try? await Task.sleep(for: delay)
                attempt += 1
            }
        }
    }

    public func decode<T: Decodable & Sendable>(_ type: T.Type, from request: NetworkRequest) async throws(NetworkError) -> T {
        let body = try await data(for: request)
        do {
            return try JSONDecoder().decode(T.self, from: body)
        } catch {
            throw .decoding(String(describing: error))
        }
    }

    private func perform(_ request: NetworkRequest) async throws(NetworkError) -> Foundation.Data {
        var urlRequest = URLRequest(url: request.url, timeoutInterval: request.timeout)
        request.headers.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }
        let body: Foundation.Data
        let response: URLResponse
        do {
            (body, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            throw Self.map(error)
        } catch {
            throw .invalidResponse
        }
        guard let http = response as? HTTPURLResponse else { throw .invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw .http(status: http.statusCode) }
        return Self.removingByteOrderMark(body)
    }

    static func removingByteOrderMark(_ body: Foundation.Data) -> Foundation.Data {
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        return body.starts(with: bom) ? body.dropFirst(bom.count) : body
    }

    static func isTransient(_ error: NetworkError) -> Bool {
        switch error {
        case .timedOut: true
        case .http(let status): status >= 500
        case .offline, .decoding, .invalidResponse: false
        }
    }

    static func map(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
             .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            .offline
        case .timedOut:
            .timedOut
        default:
            .invalidResponse
        }
    }
}
