import DomainLayer
import Foundation
import Observation

public enum OnboardingStep: Sendable, Equatable {
    case welcome
    case fuel
    case location
    /// Shown when the user picks a province by hand or doesn't share their location.
    case province
}

/// The three onboarding screens (Bear note 07, OnboardingViewModel): welcome, fuel and tank,
/// then location or a province.
@MainActor @Observable
public final class OnboardingViewModel {
    public private(set) var step: OnboardingStep = .welcome
    public var product: Product = Settings.default.product
    public private(set) var tankSize: Decimal = Settings.default.tankSize
    public private(set) var provinces: [Province] = []
    public private(set) var isFinished = false

    private let completeOnboarding: CompleteOnboarding
    private let resolveProvinces: ResolveProvinces
    private let locateUser: LocateUser

    public init(completeOnboarding: CompleteOnboarding, resolveProvinces: ResolveProvinces, locateUser: LocateUser) {
        self.completeOnboarding = completeOnboarding
        self.resolveProvinces = resolveProvinces
        self.locateUser = locateUser
    }

    // MARK: Intents

    public func next() {
        switch step {
        case .welcome: step = .fuel
        case .fuel: step = .location
        case .location, .province: break
        }
    }

    public func back() {
        switch step {
        case .welcome: break
        case .fuel: step = .welcome
        case .location: step = .fuel
        case .province: step = .location
        }
    }

    public func setTankSize(_ size: Decimal) { tankSize = Settings.clampedTankSize(size) }
    public func stepTankSize(by litres: Decimal) { setTankSize(tankSize + litres) }

    /// "Usar mi ubicación": done when allowed, otherwise on to choosing a province.
    public func useLocation() async {
        if await locateUser.authorize() == .authorized {
            await finish(province: nil)
        } else {
            await chooseProvinceByHand()
        }
    }

    public func chooseProvinceByHand() async {
        if provinces.isEmpty { provinces = await resolveProvinces.all() }
        step = .province
    }

    public func choose(_ province: ProvinceID) async {
        await finish(province: province)
    }

    private func finish(province: ProvinceID?) async {
        await completeOnboarding(product: product, tankSize: tankSize, defaultProvince: province)
        isFinished = true
    }
}
