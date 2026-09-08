import SwiftUI

public enum MacAppThemeCatalog {
    /// The shared built-in themes available to MacAppFoundation adopters.
    public static let allBuiltIn: [MacAppTheme] = [
        .system,
        githubDarkDimmed,
        midnight,
        ocean,
        aurora,
        ember,
        graphite,
        porcelain,
        blossom,
        morningMist,
        softSage,
        sunrise,
        githubLight,
    ]

    public static func theme(for id: MacAppThemeID) -> MacAppTheme? {
        allBuiltIn.first { $0.id == id }
    }

    public static let githubDarkDimmed = darkTheme(
        id: .githubDarkDimmed,
        name: "GitHub Dark Dimmed",
        caption: "Low-contrast GitHub-inspired dark",
        canvas: 0x22272E,
        canvasTop: 0x2D333B,
        surface: 0x2D333B,
        surfaceRaised: 0x373E47,
        border: 0x444C56,
        text: 0xADBAC7,
        secondaryText: 0x768390,
        accent: 0x539BF5
    )

    public static let midnight = darkTheme(
        id: .midnight,
        name: "Midnight",
        caption: "Deep blue-black with violet accents",
        canvas: 0x11131A,
        canvasTop: 0x171A24,
        surface: 0x1B1F2A,
        surfaceRaised: 0x242938,
        border: 0x343A4A,
        text: 0xF0F2F7,
        secondaryText: 0x969EAF,
        accent: 0x8B8CF8
    )

    public static let ocean = darkTheme(
        id: .ocean,
        name: "Ocean",
        caption: "Cool navy with clear blue accents",
        canvas: 0x0D1820,
        canvasTop: 0x11232E,
        surface: 0x152A36,
        surfaceRaised: 0x1C3543,
        border: 0x294655,
        text: 0xE8F2F7,
        secondaryText: 0x8AA9B8,
        accent: 0x4CB7E8
    )

    public static let aurora = darkTheme(
        id: .aurora,
        name: "Aurora",
        caption: "Dark teal with fresh green accents",
        canvas: 0x101A19,
        canvasTop: 0x14231F,
        surface: 0x192A26,
        surfaceRaised: 0x213631,
        border: 0x304A43,
        text: 0xEAF5F0,
        secondaryText: 0x91AFA4,
        accent: 0x63D6A8
    )

    public static let ember = darkTheme(
        id: .ember,
        name: "Ember",
        caption: "Warm charcoal with orange accents",
        canvas: 0x1A1513,
        canvasTop: 0x241B17,
        surface: 0x2A201C,
        surfaceRaised: 0x372923,
        border: 0x4B382F,
        text: 0xF6EEE9,
        secondaryText: 0xB39A8D,
        accent: 0xF28C52
    )

    public static let graphite = darkTheme(
        id: .graphite,
        name: "Graphite",
        caption: "Neutral charcoal with crisp contrast",
        canvas: 0x171717,
        canvasTop: 0x1D1D1D,
        surface: 0x242424,
        surfaceRaised: 0x2C2C2C,
        border: 0x3D3D3D,
        text: 0xF0F0F0,
        secondaryText: 0xA0A0A0,
        accent: 0xA7B5C6
    )

    public static let porcelain = lightTheme(
        id: .porcelain,
        name: "Porcelain",
        caption: "Clean warm neutral",
        canvas: 0xF7F5F1,
        canvasTop: 0xFBFAF7,
        surface: 0xFFFFFF,
        surfaceRaised: 0xFFFFFF,
        border: 0xDDD8D0,
        text: 0x282622,
        secondaryText: 0x777168,
        accent: 0x6078A8
    )

    public static let blossom = lightTheme(
        id: .blossom,
        name: "Blossom",
        caption: "Soft rose-tinted light",
        canvas: 0xFBF5F7,
        canvasTop: 0xFFF9FB,
        surface: 0xFFFFFF,
        surfaceRaised: 0xFFFFFF,
        border: 0xE8D9DE,
        text: 0x34282D,
        secondaryText: 0x866F78,
        accent: 0xC76688
    )

    public static let morningMist = lightTheme(
        id: .morningMist,
        name: "Morning Mist",
        caption: "Cool quiet blue-gray",
        canvas: 0xF3F6F8,
        canvasTop: 0xF8FAFB,
        surface: 0xFFFFFF,
        surfaceRaised: 0xFFFFFF,
        border: 0xD7E0E5,
        text: 0x263239,
        secondaryText: 0x6E7E87,
        accent: 0x5D88A5
    )

    public static let softSage = lightTheme(
        id: .softSage,
        name: "Soft Sage",
        caption: "Gentle green-tinted light",
        canvas: 0xF3F7F2,
        canvasTop: 0xF8FBF7,
        surface: 0xFFFFFF,
        surfaceRaised: 0xFFFFFF,
        border: 0xD6E1D3,
        text: 0x29342B,
        secondaryText: 0x718073,
        accent: 0x638B68
    )

    public static let sunrise = lightTheme(
        id: .sunrise,
        name: "Sunrise",
        caption: "Warm cream with amber accents",
        canvas: 0xFBF6ED,
        canvasTop: 0xFFF9EF,
        surface: 0xFFFFFF,
        surfaceRaised: 0xFFFFFF,
        border: 0xE8DCC8,
        text: 0x392F24,
        secondaryText: 0x867663,
        accent: 0xD8893B
    )

    public static let githubLight = lightTheme(
        id: .githubLight,
        name: "GitHub Light",
        caption: "Clean GitHub-inspired light",
        canvas: 0xF6F8FA,
        canvasTop: 0xFFFFFF,
        surface: 0xFFFFFF,
        surfaceRaised: 0xFFFFFF,
        border: 0xD0D7DE,
        text: 0x1F2328,
        secondaryText: 0x656D76,
        accent: 0x0969DA
    )

    private static func darkTheme(
        id: MacAppThemeID,
        name: String,
        caption: String,
        canvas: UInt32,
        canvasTop: UInt32,
        surface: UInt32,
        surfaceRaised: UInt32,
        border: UInt32,
        text: UInt32,
        secondaryText: UInt32,
        accent: UInt32
    ) -> MacAppTheme {
        let accentColor = Color(hex: accent)
        return MacAppTheme(
            id: id,
            name: name,
            caption: caption,
            preferredColorScheme: .dark,
            palette: MacAppThemePalette(
                canvas: Color(hex: canvas),
                canvasTop: Color(hex: canvasTop),
                surface: Color(hex: surface),
                surfaceRaised: Color(hex: surfaceRaised),
                border: Color(hex: border),
                selection: accentColor.opacity(0.16),
                textPrimary: Color(hex: text),
                textSecondary: Color(hex: secondaryText),
                textMuted: Color(hex: secondaryText).opacity(0.78),
                accent: accentColor,
                accentSoft: accentColor.opacity(0.16),
                accentForeground: .white,
                success: Color(hex: 0x57C785),
                warning: Color(hex: 0xE8A84A),
                destructive: Color(hex: 0xE06C75),
                shadow: .black.opacity(0.32)
            )
        )
    }

    private static func lightTheme(
        id: MacAppThemeID,
        name: String,
        caption: String,
        canvas: UInt32,
        canvasTop: UInt32,
        surface: UInt32,
        surfaceRaised: UInt32,
        border: UInt32,
        text: UInt32,
        secondaryText: UInt32,
        accent: UInt32
    ) -> MacAppTheme {
        let accentColor = Color(hex: accent)
        return MacAppTheme(
            id: id,
            name: name,
            caption: caption,
            preferredColorScheme: .light,
            palette: MacAppThemePalette(
                canvas: Color(hex: canvas),
                canvasTop: Color(hex: canvasTop),
                surface: Color(hex: surface),
                surfaceRaised: Color(hex: surfaceRaised),
                border: Color(hex: border),
                selection: accentColor.opacity(0.13),
                textPrimary: Color(hex: text),
                textSecondary: Color(hex: secondaryText),
                textMuted: Color(hex: secondaryText).opacity(0.78),
                accent: accentColor,
                accentSoft: accentColor.opacity(0.13),
                accentForeground: .white,
                success: Color(hex: 0x2D8A57),
                warning: Color(hex: 0xB66A18),
                destructive: Color(hex: 0xC64040),
                shadow: .black.opacity(0.14)
            )
        )
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
