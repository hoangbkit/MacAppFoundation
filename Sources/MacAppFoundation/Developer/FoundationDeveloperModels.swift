#if DEBUG
import SwiftUI

@MainActor
public struct FoundationDeveloperReplay: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String

    private let makeContent: (@escaping () -> Void) -> AnyView

    public init<Content: View>(
        id: String = UUID().uuidString,
        title: String,
        systemImage: String = "play.rectangle",
        content: @escaping (_ dismiss: @escaping () -> Void) -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.makeContent = { dismiss in AnyView(content(dismiss)) }
    }

    func content(dismiss: @escaping () -> Void) -> AnyView {
        makeContent(dismiss)
    }
}

@MainActor
public struct FoundationDeveloperDestination: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    private let makeContent: () -> AnyView

    public init<Content: View>(
        id: String = UUID().uuidString,
        title: String,
        systemImage: String = "hammer",
        content: @escaping () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.makeContent = { AnyView(content()) }
    }

    func content() -> AnyView {
        makeContent()
    }
}

@MainActor
public struct FoundationDeveloperAction: Identifiable {
    public enum Role {
        case normal
        case destructive
    }

    public let id: String
    public let title: String
    public let systemImage: String
    public let role: Role
    private let performAction: () async throws -> Void

    public init(
        id: String = UUID().uuidString,
        title: String,
        systemImage: String = "hammer",
        role: Role = .normal,
        action: @escaping () async throws -> Void
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.performAction = action
    }

    func perform() async throws {
        try await performAction()
    }
}

@MainActor
public struct FoundationDeveloperToggle: Identifiable {
    public let id: String
    public let title: String
    private let readValue: () -> Bool
    private let writeValue: (Bool) -> Void

    public init(
        id: String = UUID().uuidString,
        title: String,
        value: @escaping () -> Bool,
        setValue: @escaping (Bool) -> Void
    ) {
        self.id = id
        self.title = title
        self.readValue = value
        self.writeValue = setValue
    }

    var value: Bool { readValue() }
    func set(_ value: Bool) { writeValue(value) }
}

@MainActor
public struct FoundationDeveloperValue: Identifiable {
    public let id: String
    public let title: String
    private let readValue: () -> String

    public init(
        id: String = UUID().uuidString,
        title: String,
        value: @escaping () -> String
    ) {
        self.id = id
        self.title = title
        self.readValue = value
    }

    var value: String { readValue() }
}

public enum FoundationDeveloperItem: Identifiable {
    case action(FoundationDeveloperAction)
    case toggle(FoundationDeveloperToggle)
    case value(FoundationDeveloperValue)
    case destination(FoundationDeveloperDestination)

    public var id: String {
        switch self {
        case .action(let action): action.id
        case .toggle(let toggle): toggle.id
        case .value(let value): value.id
        case .destination(let destination): destination.id
        }
    }
}

@MainActor
public struct FoundationDeveloperSection: Identifiable {
    public let id: String
    public let title: String
    public let items: [FoundationDeveloperItem]

    public init(
        id: String = UUID().uuidString,
        title: String,
        items: [FoundationDeveloperItem]
    ) {
        self.id = id
        self.title = title
        self.items = items
    }
}

@MainActor
public struct FoundationDeveloperConfiguration {
    public var replays: [FoundationDeveloperReplay]
    public var additionalSections: [FoundationDeveloperSection]

    public init(
        replays: [FoundationDeveloperReplay] = [],
        additionalSections: [FoundationDeveloperSection] = []
    ) {
        self.replays = replays
        self.additionalSections = additionalSections
    }
}

/// Stable defaults apps may reuse when declaring their debug-only developer window.
public enum MacAppFoundationDeveloperTools {
    public static let windowID = "macappfoundation.developer-tools"
    public static let windowTitle = "Developer Tools"
    public static let defaultWidth: CGFloat = 760
    public static let defaultHeight: CGFloat = 680
}
#endif
