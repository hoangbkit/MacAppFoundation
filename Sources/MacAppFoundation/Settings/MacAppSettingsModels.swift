import SwiftUI

/// Stable identifier for a MacAppFoundation Settings pane.
///
/// Pane identifiers are open-ended so apps can mix MAF-provided panes with
/// app-specific settings without extending a framework-owned enum.
public struct MacAppSettingsPaneID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
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

public extension MacAppSettingsPaneID {
    static let appearance: Self = "appearance"
    static let plan: Self = "plan"
}

/// Stable identifier for a Settings sidebar section.
public struct MacAppSettingsSectionID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
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

public extension MacAppSettingsSectionID {
    static let application: Self = "application"
    static let account: Self = "account"
    static let features: Self = "features"
    static let advanced: Self = "advanced"
}

/// One selectable destination in ``MacAppSettingsView``.
@MainActor
public struct MacAppSettingsPane: Identifiable {
    public let id: MacAppSettingsPaneID
    public let title: String
    public let subtitle: String
    public let systemImage: String

    private let makeContent: () -> AnyView

    public init<Content: View>(
        id: MacAppSettingsPaneID,
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.makeContent = { AnyView(content()) }
    }

    func content() -> AnyView {
        makeContent()
    }
}

/// A labeled group of Settings panes displayed together in the custom sidebar.
@MainActor
public struct MacAppSettingsSection: Identifiable {
    public let id: MacAppSettingsSectionID
    public let title: String
    public let panes: [MacAppSettingsPane]

    public init(
        id: MacAppSettingsSectionID,
        title: String,
        panes: [MacAppSettingsPane]
    ) {
        self.id = id
        self.title = title
        self.panes = panes
    }
}
