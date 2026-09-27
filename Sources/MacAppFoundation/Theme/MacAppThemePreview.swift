import Foundation

/// Controls temporary previews of Pro themes for Free users.
public struct MacAppThemePreviewBehavior: Equatable, Sendable {
    public var isEnabled: Bool
    public var defaultDuration: TimeInterval
    public var preservesExpiryWhenSwitchingThemes: Bool
    public var promotesPreviewOnProUnlock: Bool
    public var schedulesAutomaticExpiration: Bool

    public init(
        isEnabled: Bool = true,
        defaultDuration: TimeInterval = 5 * 60,
        preservesExpiryWhenSwitchingThemes: Bool = true,
        promotesPreviewOnProUnlock: Bool = true,
        schedulesAutomaticExpiration: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.defaultDuration = max(0, defaultDuration)
        self.preservesExpiryWhenSwitchingThemes = preservesExpiryWhenSwitchingThemes
        self.promotesPreviewOnProUnlock = promotesPreviewOnProUnlock
        self.schedulesAutomaticExpiration = schedulesAutomaticExpiration
    }

    public static let standard = MacAppThemePreviewBehavior()
    public static let disabled = MacAppThemePreviewBehavior(isEnabled: false)
}

/// Result of choosing a theme through entitlement-aware theme UI.
public enum MacAppThemeSelectionResult: Equatable, Sendable {
    case selected(MacAppThemeID)
    case previewStarted(MacAppThemeID, expiresAt: Date)
    case requiresPro(MacAppThemeID)
    case unavailable(MacAppThemeID)
}
