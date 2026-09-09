import MacAppFoundation
import SwiftUI

enum DemoTheme {
    static let violetID = MacAppThemeID("demo-violet")

    static let violet = MacAppTheme(
        id: violetID,
        name: "Demo Violet",
        caption: "A custom theme defined by the host app",
        preferredColorScheme: .dark,
        palette: MacAppThemePalette(
            canvas: Color(red: 0.070, green: 0.055, blue: 0.105),
            canvasTop: Color(red: 0.095, green: 0.070, blue: 0.140),
            surface: Color(red: 0.105, green: 0.085, blue: 0.150),
            surfaceRaised: Color(red: 0.145, green: 0.115, blue: 0.205),
            border: Color(red: 0.285, green: 0.235, blue: 0.380),
            separator: Color(red: 0.235, green: 0.195, blue: 0.315),
            selection: Color(red: 0.335, green: 0.235, blue: 0.560).opacity(0.55),
            codeSurface: Color(red: 0.055, green: 0.045, blue: 0.085),
            textPrimary: Color(red: 0.955, green: 0.935, blue: 0.985),
            textSecondary: Color(red: 0.805, green: 0.765, blue: 0.875),
            textMuted: Color(red: 0.625, green: 0.585, blue: 0.700),
            accent: Color(red: 0.690, green: 0.470, blue: 1.000),
            accentSoft: Color(red: 0.690, green: 0.470, blue: 1.000).opacity(0.16),
            accentForeground: .white,
            success: Color(red: 0.365, green: 0.825, blue: 0.610),
            warning: Color(red: 0.955, green: 0.700, blue: 0.325),
            destructive: Color(red: 0.965, green: 0.405, blue: 0.465),
            shadow: .black.opacity(0.34)
        )
    )

    static let configuration = MacAppThemeConfiguration(
        themes: MacAppThemeCatalog.allBuiltIn + [violet],
        defaultThemeID: .system,
        storageKey: "MacAppFoundationDemo.theme"
    )
}
