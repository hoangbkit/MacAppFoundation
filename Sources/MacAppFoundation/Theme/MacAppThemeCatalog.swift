import SwiftUI

public enum MacAppThemeCatalog {
    /// The shared built-in themes available to MacAppFoundation adopters.
    ///
    /// The catalog mirrors BYOKchat's 13-theme family (including System) while
    /// using Onlink's richer palette definitions for the 12 named presets.
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

    public static let midnight = preset(
        id: .midnight,
        name: "Midnight",
        caption: "Ink & violet",
        colorScheme: .dark,
        canvas: Color(red: 0.055, green: 0.050, blue: 0.090),
        canvasTop: Color(red: 0.105, green: 0.075, blue: 0.170),
        surface: Color(red: 0.100, green: 0.090, blue: 0.145),
        surfaceRaised: Color(red: 0.135, green: 0.120, blue: 0.190),
        border: Color.white.opacity(0.10),
        text: Color(red: 0.965, green: 0.955, blue: 0.985),
        secondaryText: Color(red: 0.670, green: 0.650, blue: 0.745),
        accent: Color(red: 0.635, green: 0.455, blue: 1.000),
        accentSoft: Color(red: 0.635, green: 0.455, blue: 1.000).opacity(0.16),
        accentForeground: .black,
        success: Color(red: 0.315, green: 0.855, blue: 0.635),
        warning: Color(red: 1.000, green: 0.710, blue: 0.300),
        destructive: Color(red: 1.000, green: 0.390, blue: 0.475),
        shadow: Color.black.opacity(0.28)
    )

    public static let ocean = preset(
        id: .ocean,
        name: "Ocean",
        caption: "Deep blue",
        colorScheme: .dark,
        canvas: Color(red: 0.025, green: 0.075, blue: 0.115),
        canvasTop: Color(red: 0.035, green: 0.145, blue: 0.205),
        surface: Color(red: 0.045, green: 0.120, blue: 0.165),
        surfaceRaised: Color(red: 0.065, green: 0.165, blue: 0.215),
        border: Color(red: 0.350, green: 0.800, blue: 0.920).opacity(0.16),
        text: Color(red: 0.920, green: 0.980, blue: 1.000),
        secondaryText: Color(red: 0.560, green: 0.725, blue: 0.790),
        accent: Color(red: 0.190, green: 0.745, blue: 0.950),
        accentSoft: Color(red: 0.190, green: 0.745, blue: 0.950).opacity(0.16),
        accentForeground: .black,
        success: Color(red: 0.250, green: 0.865, blue: 0.650),
        warning: Color(red: 1.000, green: 0.710, blue: 0.300),
        destructive: Color(red: 1.000, green: 0.410, blue: 0.440),
        shadow: Color.black.opacity(0.25)
    )

    public static let aurora = preset(
        id: .aurora,
        name: "Aurora",
        caption: "Forest glow",
        colorScheme: .dark,
        canvas: Color(red: 0.035, green: 0.085, blue: 0.075),
        canvasTop: Color(red: 0.065, green: 0.145, blue: 0.120),
        surface: Color(red: 0.070, green: 0.130, blue: 0.115),
        surfaceRaised: Color(red: 0.095, green: 0.170, blue: 0.145),
        border: Color(red: 0.450, green: 0.920, blue: 0.710).opacity(0.14),
        text: Color(red: 0.930, green: 0.985, blue: 0.960),
        secondaryText: Color(red: 0.590, green: 0.745, blue: 0.675),
        accent: Color(red: 0.335, green: 0.890, blue: 0.655),
        accentSoft: Color(red: 0.335, green: 0.890, blue: 0.655).opacity(0.15),
        accentForeground: .black,
        success: Color(red: 0.335, green: 0.890, blue: 0.655),
        warning: Color(red: 1.000, green: 0.735, blue: 0.300),
        destructive: Color(red: 1.000, green: 0.430, blue: 0.450),
        shadow: Color.black.opacity(0.25)
    )

    public static let ember = preset(
        id: .ember,
        name: "Ember",
        caption: "Cinder & coral",
        colorScheme: .dark,
        canvas: Color(red: 0.105, green: 0.045, blue: 0.045),
        canvasTop: Color(red: 0.180, green: 0.070, blue: 0.065),
        surface: Color(red: 0.155, green: 0.070, blue: 0.070),
        surfaceRaised: Color(red: 0.215, green: 0.095, blue: 0.090),
        border: Color(red: 1.000, green: 0.520, blue: 0.390).opacity(0.16),
        text: Color(red: 1.000, green: 0.955, blue: 0.925),
        secondaryText: Color(red: 0.790, green: 0.625, blue: 0.570),
        accent: Color(red: 1.000, green: 0.405, blue: 0.285),
        accentSoft: Color(red: 1.000, green: 0.405, blue: 0.285).opacity(0.16),
        accentForeground: .black,
        success: Color(red: 0.370, green: 0.870, blue: 0.610),
        warning: Color(red: 1.000, green: 0.710, blue: 0.260),
        destructive: Color(red: 1.000, green: 0.320, blue: 0.390),
        shadow: Color.black.opacity(0.28)
    )

    public static let graphite = preset(
        id: .graphite,
        name: "Graphite",
        caption: "Quiet monochrome",
        colorScheme: .dark,
        canvas: Color(red: 0.060, green: 0.065, blue: 0.075),
        canvasTop: Color(red: 0.105, green: 0.110, blue: 0.125),
        surface: Color(red: 0.105, green: 0.110, blue: 0.125),
        surfaceRaised: Color(red: 0.155, green: 0.165, blue: 0.185),
        border: Color.white.opacity(0.11),
        text: Color(red: 0.965, green: 0.970, blue: 0.980),
        secondaryText: Color(red: 0.645, green: 0.665, blue: 0.705),
        accent: Color(red: 0.735, green: 0.770, blue: 0.835),
        accentSoft: Color(red: 0.735, green: 0.770, blue: 0.835).opacity(0.14),
        accentForeground: .black,
        success: Color(red: 0.350, green: 0.840, blue: 0.610),
        warning: Color(red: 0.980, green: 0.700, blue: 0.280),
        destructive: Color(red: 1.000, green: 0.390, blue: 0.450),
        shadow: Color.black.opacity(0.30)
    )

    public static let githubDarkDimmed = preset(
        id: .githubDarkDimmed,
        name: "GitHub Dark Dimmed",
        caption: "Soft developer dark",
        colorScheme: .dark,
        canvas: Color(red: 0.133, green: 0.153, blue: 0.180),
        canvasTop: Color(red: 0.110, green: 0.129, blue: 0.157),
        surface: Color(red: 0.176, green: 0.200, blue: 0.231),
        surfaceRaised: Color(red: 0.216, green: 0.243, blue: 0.278),
        border: Color(red: 0.267, green: 0.298, blue: 0.337).opacity(0.78),
        text: Color(red: 0.678, green: 0.729, blue: 0.780),
        secondaryText: Color(red: 0.463, green: 0.514, blue: 0.565),
        accent: Color(red: 0.325, green: 0.608, blue: 0.961),
        accentSoft: Color(red: 0.325, green: 0.608, blue: 0.961).opacity(0.15),
        accentForeground: .black,
        success: Color(red: 0.341, green: 0.671, blue: 0.353),
        warning: Color(red: 0.776, green: 0.565, blue: 0.149),
        destructive: Color(red: 0.898, green: 0.325, blue: 0.294),
        shadow: Color.black.opacity(0.18)
    )

    public static let porcelain = preset(
        id: .porcelain,
        name: "Porcelain",
        caption: "Warm light",
        colorScheme: .light,
        canvas: Color(red: 0.955, green: 0.945, blue: 0.920),
        canvasTop: Color(red: 0.985, green: 0.975, blue: 0.950),
        surface: Color(red: 1.000, green: 0.995, blue: 0.980),
        surfaceRaised: Color(red: 0.930, green: 0.915, blue: 0.880),
        border: Color(red: 0.180, green: 0.150, blue: 0.120).opacity(0.11),
        text: Color(red: 0.130, green: 0.115, blue: 0.105),
        secondaryText: Color(red: 0.410, green: 0.385, blue: 0.350),
        accent: Color(red: 0.385, green: 0.285, blue: 0.850),
        accentSoft: Color(red: 0.385, green: 0.285, blue: 0.850).opacity(0.10),
        success: Color(red: 0.080, green: 0.590, blue: 0.385),
        warning: Color(red: 0.850, green: 0.490, blue: 0.070),
        destructive: Color(red: 0.850, green: 0.180, blue: 0.260),
        shadow: Color.black.opacity(0.10)
    )

    public static let blossom = preset(
        id: .blossom,
        name: "Blossom",
        caption: "Rose & plum",
        colorScheme: .light,
        canvas: Color(red: 0.970, green: 0.925, blue: 0.940),
        canvasTop: Color(red: 1.000, green: 0.970, blue: 0.975),
        surface: Color(red: 1.000, green: 0.985, blue: 0.990),
        surfaceRaised: Color(red: 0.940, green: 0.870, blue: 0.900),
        border: Color(red: 0.390, green: 0.180, blue: 0.280).opacity(0.12),
        text: Color(red: 0.225, green: 0.100, blue: 0.165),
        secondaryText: Color(red: 0.500, green: 0.345, blue: 0.410),
        accent: Color(red: 0.735, green: 0.230, blue: 0.445),
        accentSoft: Color(red: 0.735, green: 0.230, blue: 0.445).opacity(0.10),
        success: Color(red: 0.090, green: 0.585, blue: 0.385),
        warning: Color(red: 0.860, green: 0.500, blue: 0.080),
        destructive: Color(red: 0.830, green: 0.165, blue: 0.300),
        shadow: Color(red: 0.300, green: 0.100, blue: 0.190).opacity(0.10)
    )

    public static let morningMist = preset(
        id: .morningMist,
        name: "Morning Mist",
        caption: "Sky & lavender",
        colorScheme: .light,
        canvas: Color(red: 0.925, green: 0.950, blue: 0.985),
        canvasTop: Color(red: 0.975, green: 0.980, blue: 1.000),
        surface: Color(red: 0.985, green: 0.990, blue: 1.000),
        surfaceRaised: Color(red: 0.865, green: 0.900, blue: 0.960),
        border: Color(red: 0.160, green: 0.290, blue: 0.520).opacity(0.12),
        text: Color(red: 0.095, green: 0.150, blue: 0.245),
        secondaryText: Color(red: 0.355, green: 0.435, blue: 0.560),
        accent: Color(red: 0.300, green: 0.420, blue: 0.900),
        accentSoft: Color(red: 0.300, green: 0.420, blue: 0.900).opacity(0.10),
        success: Color(red: 0.060, green: 0.590, blue: 0.415),
        warning: Color(red: 0.850, green: 0.500, blue: 0.070),
        destructive: Color(red: 0.820, green: 0.175, blue: 0.285),
        shadow: Color(red: 0.100, green: 0.180, blue: 0.350).opacity(0.10)
    )

    public static let softSage = preset(
        id: .softSage,
        name: "Soft Sage",
        caption: "Natural calm",
        colorScheme: .light,
        canvas: Color(red: 0.915, green: 0.945, blue: 0.905),
        canvasTop: Color(red: 0.965, green: 0.975, blue: 0.945),
        surface: Color(red: 0.985, green: 0.990, blue: 0.970),
        surfaceRaised: Color(red: 0.845, green: 0.890, blue: 0.825),
        border: Color(red: 0.150, green: 0.315, blue: 0.205).opacity(0.13),
        text: Color(red: 0.105, green: 0.190, blue: 0.130),
        secondaryText: Color(red: 0.365, green: 0.485, blue: 0.395),
        accent: Color(red: 0.145, green: 0.570, blue: 0.350),
        accentSoft: Color(red: 0.145, green: 0.570, blue: 0.350).opacity(0.11),
        accentForeground: .black,
        success: Color(red: 0.080, green: 0.570, blue: 0.350),
        warning: Color(red: 0.820, green: 0.500, blue: 0.075),
        destructive: Color(red: 0.800, green: 0.190, blue: 0.250),
        shadow: Color(red: 0.100, green: 0.260, blue: 0.150).opacity(0.09)
    )

    public static let sunrise = preset(
        id: .sunrise,
        name: "Sunrise",
        caption: "Peach & gold",
        colorScheme: .light,
        canvas: Color(red: 0.985, green: 0.925, blue: 0.850),
        canvasTop: Color(red: 1.000, green: 0.975, blue: 0.925),
        surface: Color(red: 1.000, green: 0.990, blue: 0.955),
        surfaceRaised: Color(red: 0.955, green: 0.855, blue: 0.725),
        border: Color(red: 0.450, green: 0.245, blue: 0.090).opacity(0.12),
        text: Color(red: 0.245, green: 0.130, blue: 0.070),
        secondaryText: Color(red: 0.545, green: 0.390, blue: 0.280),
        accent: Color(red: 0.930, green: 0.385, blue: 0.180),
        accentSoft: Color(red: 0.930, green: 0.385, blue: 0.180).opacity(0.11),
        accentForeground: .black,
        success: Color(red: 0.080, green: 0.570, blue: 0.360),
        warning: Color(red: 0.885, green: 0.510, blue: 0.055),
        destructive: Color(red: 0.850, green: 0.175, blue: 0.225),
        shadow: Color(red: 0.350, green: 0.175, blue: 0.050).opacity(0.10)
    )

    public static let githubLight = preset(
        id: .githubLight,
        name: "GitHub Light",
        caption: "Developer light",
        colorScheme: .light,
        canvas: Color(red: 0.965, green: 0.973, blue: 0.980),
        canvasTop: .white,
        surface: .white,
        surfaceRaised: Color(red: 0.918, green: 0.933, blue: 0.949),
        border: Color(red: 0.816, green: 0.843, blue: 0.871).opacity(0.90),
        text: Color(red: 0.122, green: 0.137, blue: 0.157),
        secondaryText: Color(red: 0.396, green: 0.427, blue: 0.463),
        accent: Color(red: 0.035, green: 0.412, blue: 0.855),
        accentSoft: Color(red: 0.035, green: 0.412, blue: 0.855).opacity(0.10),
        success: Color(red: 0.102, green: 0.498, blue: 0.216),
        warning: Color(red: 0.604, green: 0.404, blue: 0.000),
        destructive: Color(red: 0.812, green: 0.133, blue: 0.180),
        shadow: Color.black.opacity(0.08)
    )

    private static func preset(
        id: MacAppThemeID,
        name: String,
        caption: String,
        colorScheme: ColorScheme,
        canvas: Color,
        canvasTop: Color,
        surface: Color,
        surfaceRaised: Color,
        border: Color,
        text: Color,
        secondaryText: Color,
        accent: Color,
        accentSoft: Color,
        accentForeground: Color = .white,
        success: Color,
        warning: Color,
        destructive: Color,
        shadow: Color
    ) -> MacAppTheme {
        MacAppTheme(
            id: id,
            name: name,
            caption: caption,
            preferredColorScheme: colorScheme,
            palette: MacAppThemePalette(
                canvas: canvas,
                canvasTop: canvasTop,
                surface: surface,
                surfaceRaised: surfaceRaised,
                border: border,
                selection: accentSoft,
                textPrimary: text,
                textSecondary: secondaryText,
                textMuted: secondaryText.opacity(0.78),
                accent: accent,
                accentSoft: accentSoft,
                accentForeground: accentForeground,
                success: success,
                warning: warning,
                destructive: destructive,
                shadow: shadow
            )
        )
    }
}
