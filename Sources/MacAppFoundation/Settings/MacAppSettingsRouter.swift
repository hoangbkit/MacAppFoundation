import Observation

/// Lightweight selection router for ``MacAppSettingsView``.
///
/// The router does not open the macOS Settings scene itself. Host apps keep
/// ownership of `openSettings()` and use this object to tell the Settings shell
/// which pane should become active when the scene appears or is already open.
@MainActor
@Observable
public final class MacAppSettingsRouter {
    public private(set) var requestedPaneID: MacAppSettingsPaneID?
    public private(set) var requestID: UInt = 0

    public init() {}

    public func request(_ paneID: MacAppSettingsPaneID) {
        requestedPaneID = paneID
        requestID &+= 1
    }

    public func clear() {
        requestedPaneID = nil
    }
}
