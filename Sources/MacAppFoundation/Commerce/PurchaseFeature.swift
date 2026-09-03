import Foundation

/// One app capability presented consistently across purchase surfaces.
public struct PurchaseFeature: Identifiable, Hashable, Sendable {
    public let id: String
    public var systemImage: String
    public var title: String
    public var message: String
    public var freeValue: String
    public var proValue: String

    public init(
        id: String,
        systemImage: String,
        title: String,
        message: String,
        freeValue: String,
        proValue: String
    ) {
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.freeValue = freeValue
        self.proValue = proValue
    }
}
