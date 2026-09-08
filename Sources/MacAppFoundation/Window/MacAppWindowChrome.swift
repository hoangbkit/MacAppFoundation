import AppKit
import SwiftUI

/// Shared geometry for BYOKchat-style full-size macOS window chrome.
public enum MacAppWindowChromeMetrics {
    /// Height of the app-owned draggable area that replaces native title-bar spacing.
    public static let titlebarHeight: CGFloat = 44

    /// Horizontal space reserved for the native red/yellow/green traffic lights.
    public static let trafficLightReserve: CGFloat = 76
}

/// A themed draggable title-bar region that keeps native traffic lights unobstructed.
///
/// Pair this with ``View/macAppFullSizeWindowChrome()`` and a scene-level
/// `.windowStyle(.hiddenTitleBar)` to reproduce the full-size window treatment
/// used by BYOKchat's main macOS window.
@MainActor
public struct MacAppWindowDragRegion: View {
    @Environment(\.macAppTheme) private var theme

    private let trafficLightReserve: CGFloat
    private let backgroundOverride: Color?

    public init(
        trafficLightReserve: CGFloat = MacAppWindowChromeMetrics.trafficLightReserve,
        background: Color? = nil
    ) {
        self.trafficLightReserve = trafficLightReserve
        self.backgroundOverride = background
    }

    public var body: some View {
        HStack(spacing: 0) {
            if trafficLightReserve > 0 {
                Color.clear
                    .frame(width: trafficLightReserve)
                    .allowsHitTesting(false)
            }

            Color.clear
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents(true)
        }
        .frame(height: MacAppWindowChromeMetrics.titlebarHeight)
        .background(backgroundOverride ?? theme.canvas)
    }
}

public extension View {
    /// Extends app content through the native title-bar area and configures the
    /// hosting `NSWindow` to use transparent, separator-free full-size content.
    ///
    /// The scene should also use `.windowStyle(.hiddenTitleBar)`. Add a
    /// ``MacAppWindowDragRegion`` at the top of the content hierarchy so the
    /// window remains draggable and controls stay clear of the traffic lights.
    @MainActor
    func macAppFullSizeWindowChrome() -> some View {
        ignoresSafeArea(edges: .top)
            .background(MacAppFullSizeWindowConfigurator())
    }
}

@MainActor
private struct MacAppFullSizeWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        MacAppFullSizeWindowConfigurationView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

@MainActor
private final class MacAppFullSizeWindowConfigurationView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }

        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
    }
}
