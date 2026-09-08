import AppKit
import SwiftUI

/// Stable identifier for a MacAppFoundation theme.
///
/// Theme identifiers are intentionally open-ended so host apps can mix built-in
/// themes with app-specific themes without extending a framework-owned enum.
public struct MacAppThemeID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

public extension MacAppThemeID {
    static let system: Self = "system"
    static let githubDarkDimmed: Self = "github-dark-dimmed"
    static let midnight: Self = "midnight"
    static let ocean: Self = "ocean"
    static let aurora: Self = "aurora"
    static let ember: Self = "ember"
    static let graphite: Self = "graphite"
    static let porcelain: Self = "porcelain"
    static let blossom: Self = "blossom"
    static let morningMist: Self = "morning-mist"
    static let softSage: Self = "soft-sage"
    static let sunrise: Self = "sunrise"
    static let githubLight: Self = "github-light"
}

/// Semantic colors consumed by MacAppFoundation views and available to host apps.
public struct MacAppThemePalette: @unchecked Sendable {
    public let canvas: Color
    public let canvasTop: Color
    public let surface: Color
    public let surfaceRaised: Color
    public let border: Color
    public let separator: Color
    public let selection: Color
    public let codeSurface: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let textMuted: Color
    public let accent: Color
    public let accentSoft: Color
    public let accentForeground: Color
    public let success: Color
    public let warning: Color
    public let destructive: Color
    public let shadow: Color

    public init(
        canvas: Color,
        canvasTop: Color,
        surface: Color,
        surfaceRaised: Color,
        border: Color,
        separator: Color? = nil,
        selection: Color,
        codeSurface: Color? = nil,
        textPrimary: Color,
        textSecondary: Color,
        textMuted: Color,
        accent: Color,
        accentSoft: Color,
        accentForeground: Color,
        success: Color,
        warning: Color,
        destructive: Color,
        shadow: Color
    ) {
        self.canvas = canvas
        self.canvasTop = canvasTop
        self.surface = surface
        self.surfaceRaised = surfaceRaised
        self.border = border
        self.separator = separator ?? border
        self.selection = selection
        self.codeSurface = codeSurface ?? surface
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textMuted = textMuted
        self.accent = accent
        self.accentSoft = accentSoft
        self.accentForeground = accentForeground
        self.success = success
        self.warning = warning
        self.destructive = destructive
        self.shadow = shadow
    }
}

/// A complete reusable macOS theme preset.
public struct MacAppTheme: Identifiable, @unchecked Sendable {
    public let id: MacAppThemeID
    public let name: String
    public let caption: String
    public let preferredColorScheme: ColorScheme?
    public let palette: MacAppThemePalette

    public init(
        id: MacAppThemeID,
        name: String,
        caption: String,
        preferredColorScheme: ColorScheme?,
        palette: MacAppThemePalette
    ) {
        self.id = id
        self.name = name
        self.caption = caption
        self.preferredColorScheme = preferredColorScheme
        self.palette = palette
    }
}

public extension MacAppTheme {
    var canvas: Color { palette.canvas }
    var canvasTop: Color { palette.canvasTop }
    var surface: Color { palette.surface }
    var surfaceRaised: Color { palette.surfaceRaised }
    var border: Color { palette.border }
    var separator: Color { palette.separator }
    var selection: Color { palette.selection }
    var codeSurface: Color { palette.codeSurface }
    var textPrimary: Color { palette.textPrimary }
    var textSecondary: Color { palette.textSecondary }
    var textMuted: Color { palette.textMuted }
    var accent: Color { palette.accent }
    var accentSoft: Color { palette.accentSoft }
    var accentForeground: Color { palette.accentForeground }
    var success: Color { palette.success }
    var warning: Color { palette.warning }
    var destructive: Color { palette.destructive }
    var shadow: Color { palette.shadow }
}

public extension MacAppTheme {
    /// Semantic macOS theme used when an app does not inject its own theme store.
    static let system = MacAppTheme(
        id: .system,
        name: "System",
        caption: "Follow macOS appearance",
        preferredColorScheme: nil,
        palette: MacAppThemePalette(
            canvas: Color(nsColor: .windowBackgroundColor),
            canvasTop: Color(nsColor: .windowBackgroundColor),
            surface: Color(nsColor: .controlBackgroundColor),
            surfaceRaised: Color(nsColor: .underPageBackgroundColor),
            border: Color(nsColor: .separatorColor),
            separator: Color(nsColor: .separatorColor),
            selection: Color.accentColor.opacity(0.12),
            codeSurface: Color(nsColor: .textBackgroundColor),
            textPrimary: Color(nsColor: .labelColor),
            textSecondary: Color(nsColor: .secondaryLabelColor),
            textMuted: Color(nsColor: .tertiaryLabelColor),
            accent: .accentColor,
            accentSoft: Color.accentColor.opacity(0.10),
            accentForeground: .white,
            success: Color(nsColor: .systemGreen),
            warning: Color(nsColor: .systemOrange),
            destructive: Color(nsColor: .systemRed),
            shadow: .black.opacity(0.18)
        )
    )
}
