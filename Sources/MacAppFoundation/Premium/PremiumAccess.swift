import Foundation

/// A stable identifier describing why a screen or action requires Pro.
public struct PremiumFeature: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// Describes whether a feature is always available or requires an active Pro entitlement.
public enum PremiumAccessRequirement: String, Codable, Sendable {
    case free
    case pro
}

/// The result of evaluating access to a feature or an existing piece of user content.
public enum PremiumAccessDecision: Sendable, Equatable {
    case allowed
    case requiresPro(feature: PremiumFeature)
}

/// Centralizes expiry behavior used by premium gates.
///
/// Existing user-created content remains accessible by default after Pro expires.
/// Apps can still gate creation and premium editing without making user data
/// inaccessible simply because an entitlement ended.
public struct PremiumAccessPolicy: Sendable, Equatable {
    public var existingContentRemainsAccessible: Bool

    public init(existingContentRemainsAccessible: Bool = true) {
        self.existingContentRemainsAccessible = existingContentRemainsAccessible
    }

    public func decision(
        for feature: PremiumFeature,
        requirement: PremiumAccessRequirement,
        hasPro: Bool,
        isExistingContent: Bool = false
    ) -> PremiumAccessDecision {
        guard requirement == .pro, !hasPro else {
            return .allowed
        }

        if isExistingContent, existingContentRemainsAccessible {
            return .allowed
        }

        return .requiresPro(feature: feature)
    }
}
