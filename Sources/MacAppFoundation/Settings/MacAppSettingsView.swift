import SwiftUI

/// BYOKchat-inspired macOS Settings shell with an app-extensible pane model.
///
/// MacAppFoundation owns the themed sidebar, selection interactions, detail
/// header, separators, and content canvas. Flat panes are the recommended default
/// for small Settings surfaces; apps can opt into labeled sections when stronger
/// grouping is useful.
@MainActor
public struct MacAppSettingsView: View {
    private let title: String
    private let systemImage: String
    private let sections: [MacAppSettingsSection]
    private let router: MacAppSettingsRouter?

    @Environment(\.macAppTheme) private var theme
    @State private var selectionID: MacAppSettingsPaneID?

    /// Creates the recommended flat Settings sidebar.
    public init(
        title: String = "Settings",
        systemImage: String = "gearshape.fill",
        panes: [MacAppSettingsPane],
        initialSelection: MacAppSettingsPaneID? = nil,
        router: MacAppSettingsRouter? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.sections = [
            MacAppSettingsSection(
                id: "macappfoundation.flat",
                title: "",
                panes: panes
            )
        ]
        self.router = router
        _selectionID = State(initialValue: initialSelection)
    }

    /// Creates a Settings sidebar with explicit labeled sections.
    ///
    /// Prefer the `panes:` initializer for smaller apps. Sections are useful when
    /// a larger Settings surface benefits from distinct conceptual groups.
    public init(
        title: String = "Settings",
        systemImage: String = "gearshape.fill",
        sections: [MacAppSettingsSection],
        initialSelection: MacAppSettingsPaneID? = nil,
        router: MacAppSettingsRouter? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.sections = sections
        self.router = router
        _selectionID = State(initialValue: initialSelection)
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 218)

            Rectangle()
                .fill(theme.separator.opacity(0.85))
                .frame(width: 1)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.canvas)
        }
        .frame(minWidth: 900, idealWidth: 940, minHeight: 620, idealHeight: 660)
        .background(theme.canvas)
        .groupBoxStyle(MacAppSettingsGroupBoxStyle())
        .onAppear {
            consumeRouterRequest()
            normalizeSelection()
        }
        .onChange(of: router?.requestID ?? 0) { _, _ in
            consumeRouterRequest()
        }
        .onChange(of: paneIDs) { _, _ in
            consumeRouterRequest()
            normalizeSelection()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(sections.filter { !$0.panes.isEmpty }) { section in
                        settingsSidebarSection(section)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.top, 14)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)

            Spacer(minLength: 0)
        }
        .background(theme.surface)
    }

    private func settingsSidebarSection(_ section: MacAppSettingsSection) -> some View {
        VStack(alignment: .leading, spacing: section.title.isEmpty ? 0 : 5) {
            if !section.title.isEmpty {
                Text(section.title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textMuted.opacity(0.82))
                    .tracking(0.55)
                    .padding(.horizontal, 9)
                    .padding(.bottom, 1)
            }

            ForEach(section.panes) { pane in
                MacAppSettingsSidebarRow(
                    title: pane.title,
                    systemImage: pane.systemImage,
                    isSelected: selectionID == pane.id
                ) {
                    selectionID = pane.id
                }
            }
        }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            if let selectedPane {
                MacAppSettingsDetailHeader(
                    title: selectedPane.title,
                    subtitle: selectedPane.subtitle,
                    systemImage: selectedPane.systemImage
                )

                Rectangle()
                    .fill(theme.separator.opacity(0.72))
                    .frame(height: 1)

                selectedPane.content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.canvas)
            } else {
                ContentUnavailableView(
                    "No Settings",
                    systemImage: "gearshape",
                    description: Text("Add at least one settings pane to this shell.")
                )
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.canvas)
            }
        }
    }

    private var allPanes: [MacAppSettingsPane] {
        sections.flatMap(\.panes)
    }

    private var paneIDs: [MacAppSettingsPaneID] {
        allPanes.map(\.id)
    }

    private var selectedPane: MacAppSettingsPane? {
        guard let selectionID else { return nil }
        return allPanes.first { $0.id == selectionID }
    }

    private func normalizeSelection() {
        if let selectionID, paneIDs.contains(selectionID) {
            return
        }
        selectionID = allPanes.first?.id
    }

    private func consumeRouterRequest() {
        guard let router,
              let requestedPaneID = router.requestedPaneID,
              paneIDs.contains(requestedPaneID)
        else { return }

        selectionID = requestedPaneID
        router.clear()
    }
}

private struct MacAppSettingsSidebarRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.macAppTheme) private var theme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? theme.accent : theme.textMuted)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(theme.textPrimary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(height: 32)
            .contentShape(Rectangle())
            .background(
                rowBackground,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(theme.accent.opacity(0.18), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    private var rowBackground: Color {
        if isSelected { return theme.selection }
        if isHovering { return theme.selection.opacity(0.48) }
        return .clear
    }
}

private struct MacAppSettingsDetailHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    @Environment(\.macAppTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 34, height: 34)
                .background(
                    theme.accentSoft,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .frame(height: 72)
        .background(theme.canvas)
    }
}

/// Theme-aware group-box chrome used automatically by ``MacAppSettingsView``.
///
/// App-injected pane content can use normal SwiftUI `GroupBox` controls and they
/// inherit this style from the settings shell without adopting app-specific tokens.
public struct MacAppSettingsGroupBoxStyle: GroupBoxStyle {
    @Environment(\.macAppTheme) private var theme

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            configuration.content
                .foregroundStyle(theme.textPrimary)
        }
        .padding(16)
        .background(
            theme.surface,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.separator.opacity(0.82), lineWidth: 1)
        }
    }
}
