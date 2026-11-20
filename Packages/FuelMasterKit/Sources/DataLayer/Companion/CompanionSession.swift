import Foundation

/// The channel between the iPhone app and the watch app. `WatchConnectivitySession` in the apps,
/// a fake in tests. Payloads are encoded `CompanionContext` / `CompanionRequest` values.
public protocol CompanionSession: Sendable {
    /// Starts the session. Subscribe to the received streams first, so nothing is missed.
    func activate() async
    /// iPhone → watch: replaces the context the watch sees. Kept until it can be delivered.
    func send(context: Data) async
    /// Watch → iPhone: delivered now when the iPhone is reachable (waking its app), otherwise
    /// queued and delivered once it is, even after the apps were closed. Requests may arrive twice.
    func send(request: Data) async
    func receivedContexts() async -> AsyncStream<Data>
    func receivedRequests() async -> AsyncStream<Data>
    /// The last context delivered to this device, also from an earlier launch.
    func latestReceivedContext() async -> Data?
}

#if canImport(WatchConnectivity)
import OSLog
import WatchConnectivity

/// `CompanionSession` over WatchConnectivity: application context one way, user info the other.
/// WCSession calls its delegate on a background queue; the lock guards the state shared with it.
public final class WatchConnectivitySession: NSObject, CompanionSession, WCSessionDelegate, @unchecked Sendable {
    private static let payloadKey = "payload"
    /// WatchConnectivity skips a context equal to the last one, so a resend carries the time too.
    private static let resentAtKey = "resentAt"

    private let session: WCSession
    private let lock = NSLock()
    private var pendingContext: Data?
    private var isResend = false
    /// The last context handed to WatchConnectivity, sent again if the watch app is reinstalled.
    private var lastContext: Data?
    private var pendingRequests: [Data] = []
    private var contextContinuation: AsyncStream<Data>.Continuation?
    private var requestContinuation: AsyncStream<Data>.Continuation?

    public init(session: WCSession = .default) {
        self.session = session
    }

    public func activate() async {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    public func send(context: Data) async {
        lock.withLock { pendingContext = context }
        flush()
    }

    public func send(request: Data) async {
        lock.withLock { pendingRequests.append(request) }
        flush()
    }

    public func receivedContexts() async -> AsyncStream<Data> {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        lock.withLock { contextContinuation = continuation }
        return stream
    }

    public func receivedRequests() async -> AsyncStream<Data> {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        lock.withLock { requestContinuation = continuation }
        return stream
    }

    public func latestReceivedContext() async -> Data? {
        guard WCSession.isSupported() else { return nil }
        return session.receivedApplicationContext[Self.payloadKey] as? Data
    }

    /// Sends whatever is waiting, once the session is active and the other app can receive it.
    private func flush() {
        guard WCSession.isSupported(), session.activationState == .activated else { return }
        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return }
        #endif
        let (context, requests) = lock.withLock {
            defer { pendingRequests = [] }
            return (pendingContext, pendingRequests)
        }
        for request in requests {
            let payload = [Self.payloadKey: request]
            guard session.isReachable else {
                session.transferUserInfo(payload)
                continue
            }
            // A live message also wakes the iPhone app; queued user info waits for it to open.
            // Requests can be applied twice, so falling back after a late error is safe.
            session.sendMessage(payload, replyHandler: nil) { [session] _ in
                session.transferUserInfo(payload)
            }
        }
        if !requests.isEmpty { Logger.companion.info("Requests queued for the iPhone: \(requests.count)") }
        guard let context else { return }
        var payload: [String: Any] = [Self.payloadKey: context]
        if lock.withLock({ isResend }) { payload[Self.resentAtKey] = Date.now }
        do {
            try session.updateApplicationContext(payload)
            lock.withLock {
                if pendingContext == context { pendingContext = nil }
                lastContext = context
                isResend = false
            }
        } catch {
            // Stays pending: sent again on the next change or activation.
            Logger.companion.error("Context not sent: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - WCSessionDelegate

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                        error: (any Error)?) {
        if let error { Logger.companion.error("Activation failed: \(error.localizedDescription, privacy: .public)") }
        flush()
    }

    public func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer,
                        error: (any Error)?) {
        guard let error else { return }
        Logger.companion.error("Request not delivered: \(error.localizedDescription, privacy: .public)")
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[Self.payloadKey] as? Data else { return }
        _ = lock.withLock { contextContinuation?.yield(data) }
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receive(request: userInfo)
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(request: message)
    }

    private func receive(request payload: [String: Any]) {
        guard let data = payload[Self.payloadKey] as? Data else { return }
        _ = lock.withLock { requestContinuation?.yield(data) }
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}

    /// After switching to another watch: activate again for the new one.
    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// The watch app may be installed after the iPhone app sent its context.
    public func sessionWatchStateDidChange(_ session: WCSession) {
        if session.isWatchAppInstalled {
            lock.withLock {
                if pendingContext == nil, let lastContext {
                    pendingContext = lastContext
                    isResend = true
                }
            }
        }
        flush()
    }
    #endif
}
#endif
