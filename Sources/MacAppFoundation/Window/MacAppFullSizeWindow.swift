import SwiftUI

/// A reusable macOS window scene with full-size content, transparent hidden title bar,
/// native traffic lights, and an app-owned draggable title-bar region.
///
/// The host app owns the window's identity and default size while
/// MacAppFoundation supplies the same window chrome used by its demo surfaces.
@MainActor
public struct MacAppFullSizeWindow<Content: View>: Scene {
    private let title: String
    private let id: String
    private let defaultWidth: CGFloat
    private let defaultHeight: CGFloat
    private let showsDefaultDragRegion: Bool
    private let content: Content

    public init(
        _ title: String,
        id: String,
        defaultWidth: CGFloat,
        defaultHeight: CGFloat,
        showsDefaultDragRegion: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.id = id
        self.defaultWidth = defaultWidth
        self.defaultHeight = defaultHeight
        self.showsDefaultDragRegion = showsDefaultDragRegion
        self.content = content()
    }

    public var body: some Scene {
        Window(title, id: id) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    if showsDefaultDragRegion {
                        MacAppWindowDragRegion(background: .clear)
                    }
                }
                .macAppFullSizeWindowChrome()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: defaultWidth, height: defaultHeight)
        .windowResizability(.contentSize)
    }
}
