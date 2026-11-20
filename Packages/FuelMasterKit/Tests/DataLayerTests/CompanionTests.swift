@testable import DataLayer
import DomainLayer
import Foundation
import Testing

// iPhone ↔ watch sync (Bear note 06): CompanionSync on the iPhone, CompanionMirrorRepository on
// the watch, both over a fake session.

actor FakeCompanionSession: CompanionSession {
    private(set) var sentContexts: [CompanionContext] = []
    private(set) var sentRequests: [CompanionRequest] = []
    var latest: Data?
    private var contextContinuation: AsyncStream<Data>.Continuation?
    private var requestContinuation: AsyncStream<Data>.Continuation?

    func activate() async {}

    func send(context: Data) async {
        sentContexts.append(try! JSONDecoder().decode(CompanionContext.self, from: context))
    }

    func send(request: Data) async {
        sentRequests.append(try! JSONDecoder().decode(CompanionRequest.self, from: request))
    }

    func receivedContexts() async -> AsyncStream<Data> {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        contextContinuation = continuation
        return stream
    }

    func receivedRequests() async -> AsyncStream<Data> {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        requestContinuation = continuation
        return stream
    }

    func latestReceivedContext() async -> Data? { latest }

    func setLatest(_ context: CompanionContext) { latest = try! JSONEncoder().encode(context) }

    func deliver(_ context: CompanionContext) { contextContinuation?.yield(try! JSONEncoder().encode(context)) }

    func deliver(_ request: CompanionRequest) { requestContinuation?.yield(try! JSONEncoder().encode(request)) }

    var isListening: Bool { contextContinuation != nil || requestContinuation != nil }
}

/// Holds the first `send(request:)` until the test releases it, to open the window in which
/// another call can run on the mirror actor.
actor GatedCompanionSession: CompanionSession {
    private var gate: CheckedContinuation<Void, Never>?
    var isHoldingRequest: Bool { gate != nil }

    func activate() async {}
    func send(context: Data) async {}
    func send(request: Data) async { await withCheckedContinuation { gate = $0 } }
    func receivedContexts() async -> AsyncStream<Data> { AsyncStream { $0.finish() } }
    func receivedRequests() async -> AsyncStream<Data> { AsyncStream { $0.finish() } }
    func latestReceivedContext() async -> Data? { nil }
    func release() {
        gate?.resume()
        gate = nil
    }
}

/// No favourites; the first read waits until the test releases it.
actor GatedFavorites: FavoriteStationsRepository {
    private var gate: CheckedContinuation<Void, Never>?
    private var holdsNextRead = true
    var isHoldingRead: Bool { gate != nil }

    func favorites() async throws -> [FavoriteEntry] {
        if holdsNextRead {
            holdsNextRead = false
            await withCheckedContinuation { gate = $0 }
        }
        return []
    }
    func add(_ station: StationID, province: ProvinceID) async throws {}
    func remove(_ station: StationID) async throws {}
    func move(from source: Int, to destination: Int) async throws {}
    func changes() async -> AsyncStream<[FavoriteEntry]> { AsyncStream { $0.finish() } }
    func iCloudStatus() async -> AsyncStream<ICloudStatus> { AsyncStream { $0.finish() } }
    func release() {
        gate?.resume()
        gate = nil
    }
}

/// A clock the test moves by hand.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    init(_ seconds: TimeInterval) { date = Date(timeIntervalSince1970: seconds) }
    var now: Date { lock.withLock { date } }
    func set(_ seconds: TimeInterval) { lock.withLock { date = Date(timeIntervalSince1970: seconds) } }
}

/// Waits up to about two seconds for something a running loop does.
func eventually(_ condition: () async -> Bool) async -> Bool {
    for _ in 0..<200 {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return false
}

private func freshDefaults() -> UserDefaults { UserDefaults(suiteName: "tests.\(UUID())")! }

private func at(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

private let ballenoil = StationID("3213")
private let shellGoya = StationID("2909")
private let madrid = ProvinceID("28")

private func context(product: Product = .diesel, changedAt: TimeInterval = 0, scale: PriceScale = .trafficLight,
                     favorites: [StationID] = [], location: Coordinate? = nil) -> CompanionContext {
    CompanionContext(product: product, productChangedAt: at(changedAt), accent: .preset(.blue), priceScale: scale,
                     defaultProvinceID: madrid, lastViewedProvinceID: madrid, lastLocation: location,
                     favorites: favorites.map { CompanionFavorite(stationID: $0, provinceID: madrid) })
}

@Suite("Companion sync on the iPhone")
struct CompanionSyncTests {
    let session = FakeCompanionSession()
    let clock = TestClock(1_000)
    let settings: LocalDataRepository
    let favorites: FavoritesRepository
    let sync: CompanionSync

    init() throws {
        settings = LocalDataRepository(container: try PersistenceFactory.cacheContainer(inMemory: true),
                                       defaults: freshDefaults())
        favorites = FavoritesRepository(container: try PersistenceFactory.favoritesContainer(inMemory: true))
        let clock = clock
        sync = CompanionSync(session: session, settings: settings, favorites: favorites,
                             defaults: freshDefaults(), now: { clock.now })
    }

    @Test func sendsSettingsAndFavouritesInOrder() async throws {
        await settings.update { $0.priceScale = .blueOrange }
        try await favorites.add(ballenoil, province: madrid)
        try await favorites.add(shellGoya, province: madrid)

        await sync.sendContext()

        let sent = try #require(await session.sentContexts.last)
        #expect(sent.product == .diesel)
        #expect(sent.priceScale == .blueOrange)
        #expect(sent.favorites.map(\.stationID) == [ballenoil, shellGoya])
        // A fresh install never chose a fuel, so the watch's choice wins.
        #expect(sent.productChangedAt == .distantPast)
    }

    @Test func doesNotResendTheSameContext() async {
        await sync.sendContext()
        await sync.sendContext()
        #expect(await session.sentContexts.count == 1)
    }

    @Test func appliesFavouritesFromTheWatch() async throws {
        await sync.handle(.addFavorite(ballenoil, province: madrid))
        #expect(try await favorites.favorites().map(\.stationID) == [ballenoil])
        await sync.handle(.removeFavorite(ballenoil))
        #expect(try await favorites.favorites().isEmpty)
    }

    @Test func takesANewerFuelFromTheWatch() async {
        await sync.sendContext()
        await sync.handle(.setProduct(.petrol95E5, changedAt: at(500)))
        #expect(await settings.current().product == .petrol95E5)
        await sync.sendContext()
        #expect(await session.sentContexts.last?.productChangedAt == at(500))
    }

    @Test func keepsAFuelChosenOnTheIPhoneAfterTheWatchChange() async {
        await sync.sendContext()
        let current = await settings.update { $0.product = .lpg }
        await sync.settingsChanged(current)       // changed on the iPhone at 1 000 s

        await sync.handle(.setProduct(.petrol95E5, changedAt: at(500)))   // queued earlier on the watch

        #expect(await settings.current().product == .lpg)
        #expect(await session.sentContexts.last?.productChangedAt == at(1_000))
    }

    /// A change made while a context is being built must not be followed by that older context.
    @Test func lastContextSentIsTheNewest() async throws {
        let favorites = GatedFavorites()
        let sync = CompanionSync(session: session, settings: settings, favorites: favorites, defaults: freshDefaults())

        async let first: Void = sync.sendContext()          // reads the settings, then waits on favourites
        #expect(await eventually { await favorites.isHoldingRead })
        await settings.update { $0.priceScale = .blueOrange }
        await sync.sendContext()
        await favorites.release()
        await first

        #expect(await session.sentContexts.last?.priceScale == .blueOrange)
    }

    @Test func runAppliesQueuedRequestsAndSendsChanges() async throws {
        let task = Task { await sync.run() }
        defer { task.cancel() }
        let started = await eventually {
            let listening = await session.isListening
            let sent = await session.sentContexts
            return listening && !sent.isEmpty
        }
        #expect(started)

        await session.deliver(.addFavorite(ballenoil, province: madrid))

        let applied = await eventually { (try? await favorites.favorites().count) == 1 }
        #expect(applied)
        let resent = await eventually {
            let last = await session.sentContexts.last
            return last?.favorites.map(\.stationID) == [ballenoil]
        }
        #expect(resent)
    }
}

@Suite("Companion mirror on the watch")
struct CompanionMirrorTests {
    let session = FakeCompanionSession()
    let clock = TestClock(1_000)
    /// The same suite for every mirror in a test, so a second one reads what the first saved.
    let suite = "tests.\(UUID())"

    func makeMirror() -> CompanionMirrorRepository {
        let clock = clock
        return CompanionMirrorRepository(session: session, defaults: UserDefaults(suiteName: suite)!, now: { clock.now })
    }

    @Test func startsWithoutOnboarding() async throws {
        let mirror = makeMirror()
        #expect(await mirror.current().onboardingCompleted)
        #expect(try await mirror.favorites().isEmpty)
    }

    @Test func takesTheIPhoneContextAndKeepsIt() async throws {
        let mirror = makeMirror()
        await mirror.apply(context(product: .lpg, changedAt: 10, scale: .monochrome, favorites: [shellGoya, ballenoil]))

        #expect(await mirror.current().product == .lpg)
        #expect(await mirror.current().priceScale == .monochrome)
        #expect(await mirror.current().accent == .preset(.blue))
        #expect(try await mirror.favorites().map(\.stationID) == [shellGoya, ballenoil])

        let relaunched = makeMirror()
        #expect(await relaunched.current().product == .lpg)
        #expect(try await relaunched.favorites().map(\.order) == [0, 1])
    }

    @Test func sendsAFuelChosenOnTheWatch() async {
        let mirror = makeMirror()
        await mirror.update { $0.product = .petrol98E5 }
        #expect(await session.sentRequests == [.setProduct(.petrol98E5, changedAt: at(1_000))])
    }

    /// The iPhone's context can arrive while a fuel change waits to reach the iPhone; saving the
    /// change must not put back the favourites from before that context.
    @Test func contextArrivingDuringAFuelChangeIsKept() async throws {
        let session = GatedCompanionSession()
        let clock = clock
        let mirror = CompanionMirrorRepository(session: session, defaults: UserDefaults(suiteName: suite)!,
                                               now: { clock.now })

        async let change = mirror.update { $0.product = .petrol98E5 }
        #expect(await eventually { await session.isHoldingRequest })
        await mirror.apply(context(product: .diesel, changedAt: 0, favorites: [ballenoil]))
        await session.release()
        #expect(await change.product == .petrol98E5)

        #expect(try await mirror.favorites().map(\.stationID) == [ballenoil])
        #expect(await mirror.current().product == .petrol98E5)
    }

    @Test func olderContextKeepsTheWatchFuel() async {
        let mirror = makeMirror()
        await mirror.update { $0.product = .petrol98E5 }               // at 1 000 s

        await mirror.apply(context(product: .diesel, changedAt: 900, scale: .blueOrange))
        #expect(await mirror.current().product == .petrol98E5)
        #expect(await mirror.current().priceScale == .blueOrange)

        await mirror.apply(context(product: .lpg, changedAt: 1_100))
        #expect(await mirror.current().product == .lpg)
    }

    @Test func favouriteOnTheWatchShowsAtOnceAndGoesToTheIPhone() async throws {
        let mirror = makeMirror()
        try await mirror.add(ballenoil, province: madrid)
        try await mirror.add(ballenoil, province: madrid)
        #expect(try await mirror.favorites().map(\.stationID) == [ballenoil])
        try await mirror.remove(ballenoil)
        #expect(try await mirror.favorites().isEmpty)
        #expect(await session.sentRequests == [.addFavorite(ballenoil, province: madrid), .removeFavorite(ballenoil)])
    }

    @Test func iPhoneAreaIsOnlyAStartingPoint() async {
        let mirror = makeMirror()
        let sol = Coordinate(latitude: 40.4169, longitude: -3.7035)
        await mirror.apply(context(location: sol))
        #expect(await mirror.current().lastLocation == sol)

        let valencia = Coordinate(latitude: 39.47, longitude: -0.376)
        await mirror.update { $0.lastLocation = valencia }
        await mirror.apply(context(location: sol))
        #expect(await mirror.current().lastLocation == valencia)
        #expect(await session.sentRequests.isEmpty)
    }

    @Test func runAppliesTheLastDeliveredContextThenNewOnes() async throws {
        let mirror = makeMirror()
        let changes = await mirror.changes() as AsyncStream<[FavoriteEntry]>
        await session.setLatest(context(favorites: [ballenoil]))

        let task = Task { await mirror.run() }
        defer { task.cancel() }
        let first = await eventually { (try? await mirror.favorites().count) == 1 }
        #expect(first)

        await session.deliver(context(favorites: [ballenoil, shellGoya]))
        let second = await eventually { (try? await mirror.favorites().count) == 2 }
        #expect(second)

        var iterator = changes.makeAsyncIterator()
        #expect(await iterator.next()?.isEmpty == false)
    }
}
