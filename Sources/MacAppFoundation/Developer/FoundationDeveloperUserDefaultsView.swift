#if DEBUG
import AppKit
import Combine
import CoreFoundation
import Foundation
import SwiftUI

enum FoundationDeveloperUserDefaultsValueType: String, CaseIterable, Identifiable {
    case string
    case bool
    case integer
    case double
    case date
    case data
    case array
    case dictionary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .string: "String"
        case .bool: "Bool"
        case .integer: "Integer"
        case .double: "Double"
        case .date: "Date"
        case .data: "Data"
        case .array: "Array"
        case .dictionary: "Dictionary"
        }
    }

    var systemImage: String {
        switch self {
        case .string: "textformat"
        case .bool: "switch.2"
        case .integer: "number"
        case .double: "function"
        case .date: "calendar"
        case .data: "doc.on.clipboard"
        case .array: "list.bullet"
        case .dictionary: "curlybraces"
        }
    }
}

struct FoundationDeveloperUserDefaultRow: Identifiable {
    var id: String { key }

    let key: String
    let type: FoundationDeveloperUserDefaultsValueType
    let value: Any
    let displayValue: String
    let isPersistent: Bool
}

enum FoundationDeveloperUserDefaultsCodec {
    static func valueType(for value: Any) -> FoundationDeveloperUserDefaultsValueType? {
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool
            }

            let encoding = String(cString: number.objCType)
            if encoding == "f" || encoding == "d" {
                return .double
            }
            return .integer
        }

        if value is String { return .string }
        if value is Date { return .date }
        if value is Data { return .data }
        if value is [Any] { return .array }
        if value is [String: Any] { return .dictionary }
        return nil
    }

    static func displayValue(_ value: Any) -> String {
        switch valueType(for: value) {
        case .string:
            return value as? String ?? ""
        case .bool:
            return (value as? NSNumber)?.boolValue == true ? "true" : "false"
        case .integer:
            return String((value as? NSNumber)?.int64Value ?? 0)
        case .double:
            return String((value as? NSNumber)?.doubleValue ?? 0)
        case .date:
            guard let date = value as? Date else { return "Invalid date" }
            return ISO8601DateFormatter().string(from: date)
        case .data:
            return "\((value as? Data)?.count ?? 0) bytes"
        case .array:
            return "\((value as? [Any])?.count ?? 0) items"
        case .dictionary:
            return "\((value as? [String: Any])?.count ?? 0) keys"
        case nil:
            return String(describing: value)
        }
    }

    static func copyValue(_ value: Any) -> String {
        switch valueType(for: value) {
        case .data:
            return (value as? Data)?.base64EncodedString() ?? ""
        case .array, .dictionary:
            return propertyListText(value) ?? String(describing: value)
        default:
            return displayValue(value)
        }
    }

    static func propertyListText(_ value: Any) -> String? {
        guard PropertyListSerialization.propertyList(value, isValidFor: .xml) else {
            return nil
        }
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: value,
            format: .xml,
            options: 0
        ) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func propertyListValue(
        from text: String,
        expectedType: FoundationDeveloperUserDefaultsValueType
    ) throws -> Any {
        let data = Data(text.utf8)
        let value = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )

        switch expectedType {
        case .array where value is [Any]:
            return value
        case .dictionary where value is [String: Any]:
            return value
        case .array:
            throw FoundationDeveloperUserDefaultsError.invalidValue(
                "The property list root must be an array."
            )
        case .dictionary:
            throw FoundationDeveloperUserDefaultsError.invalidValue(
                "The property list root must be a dictionary."
            )
        default:
            return value
        }
    }

    static func emptyPropertyList(for type: FoundationDeveloperUserDefaultsValueType) -> String {
        let value: Any = type == .array ? [Any]() : [String: Any]()
        return propertyListText(value) ?? ""
    }
}

enum FoundationDeveloperUserDefaultsError: LocalizedError {
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .invalidValue(let message):
            message
        }
    }
}

@MainActor
final class FoundationDeveloperUserDefaultsModel: ObservableObject {
    @Published private(set) var rows: [FoundationDeveloperUserDefaultRow] = []

    let defaults: UserDefaults
    let domainName: String?

    init(
        defaults: UserDefaults = .standard,
        domainName: String? = Bundle.main.bundleIdentifier
    ) {
        self.defaults = defaults
        self.domainName = domainName
        refresh()
    }

    func refresh() {
        let effective = defaults.dictionaryRepresentation()
        let persistentKeys: Set<String>
        if let domainName {
            persistentKeys = Set(
                (defaults.persistentDomain(forName: domainName) ?? [:]).keys
            )
        } else {
            persistentKeys = []
        }

        rows = effective
            .compactMap { key, value -> FoundationDeveloperUserDefaultRow? in
                guard let type = FoundationDeveloperUserDefaultsCodec.valueType(for: value) else {
                    return nil
                }
                return FoundationDeveloperUserDefaultRow(
                    key: key,
                    type: type,
                    value: value,
                    displayValue: FoundationDeveloperUserDefaultsCodec.displayValue(value),
                    isPersistent: persistentKeys.contains(key)
                )
            }
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    func set(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        refresh()
    }

    func removeValue(forKey key: String) {
        defaults.removeObject(forKey: key)
        refresh()
    }

    func resetPersistentDomain() {
        guard let domainName else { return }
        defaults.removePersistentDomain(forName: domainName)
        refresh()
    }
}

private struct FoundationDeveloperUserDefaultsEditorContext: Identifiable {
    let id = UUID()
    let row: FoundationDeveloperUserDefaultRow?

    var title: String {
        row == nil ? "Add User Default" : "Edit User Default"
    }
}

@MainActor
struct FoundationDeveloperUserDefaultsView: View {
    @Environment(\.macAppTheme) private var theme

    @StateObject private var model: FoundationDeveloperUserDefaultsModel
    @State private var searchText = ""
    @State private var editor: FoundationDeveloperUserDefaultsEditorContext?
    @State private var pendingDelete: FoundationDeveloperUserDefaultRow?
    @State private var resetConfirmationPresented = false
    @State private var statusMessage: String?

    init(
        defaults: UserDefaults = .standard,
        domainName: String? = Bundle.main.bundleIdentifier
    ) {
        _model = StateObject(
            wrappedValue: FoundationDeveloperUserDefaultsModel(
                defaults: defaults,
                domainName: domainName
            )
        )
    }

    var body: some View {
        List {
            Section("Domain") {
                LabeledContent(
                    "Persistent domain",
                    value: model.domainName ?? "Unavailable"
                )
                LabeledContent("Visible values", value: "\(model.rows.count)")
                LabeledContent(
                    "Stored values",
                    value: "\(model.rows.filter(\.isPersistent).count)"
                )
            }

            Section {
                if filteredRows.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No User Defaults" : "No Matches",
                        systemImage: "slider.horizontal.3",
                        description: Text(
                            searchText.isEmpty
                                ? "This app currently has no supported UserDefaults values."
                                : "No keys or values match your search."
                        )
                    )
                } else {
                    ForEach(filteredRows) { row in
                        userDefaultRow(row)
                    }
                }
            } header: {
                HStack {
                    Text("Values")
                    Spacer()
                    Text("\(filteredRows.count)")
                        .font(.caption)
                        .foregroundStyle(theme.textMuted)
                }
            } footer: {
                Text("Stored values live in the app's persistent domain. Effective-only values come from registration or another UserDefaults search domain; editing one creates an app-domain override.")
                    .foregroundStyle(theme.textSecondary)
            }

            Section("Developer Actions") {
                Button("Reset App UserDefaults", systemImage: "trash", role: .destructive) {
                    resetConfirmationPresented = true
                }
                .disabled(model.domainName == nil || !model.rows.contains(where: \.isPersistent))

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
        .searchable(text: $searchText, prompt: "Search keys or values")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    editor = FoundationDeveloperUserDefaultsEditorContext(row: nil)
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .help("Add a UserDefaults value")

                Button {
                    model.refresh()
                    statusMessage = "UserDefaults refreshed."
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh UserDefaults")
            }
        }
        .sheet(item: $editor) { context in
            FoundationDeveloperUserDefaultsEditorSheet(
                context: context
            ) { key, value in
                model.set(value, forKey: key)
                statusMessage = "Saved \(key)."
            }
        }
        .confirmationDialog(
            "Delete UserDefaults Value?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { row in
            Button("Delete \(row.key)", role: .destructive) {
                model.removeValue(forKey: row.key)
                statusMessage = "Deleted stored value for \(row.key)."
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: { row in
            Text(
                row.isPersistent
                    ? "The app-domain value will be removed. A registered or inherited fallback may become visible afterward."
                    : "This value is not stored in the app domain, so there is no persistent value to delete."
            )
        }
        .confirmationDialog(
            "Reset App UserDefaults?",
            isPresented: $resetConfirmationPresented
        ) {
            Button("Reset App UserDefaults", role: .destructive) {
                model.resetPersistentDomain()
                statusMessage = "App UserDefaults domain reset."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every value stored in the app's persistent UserDefaults domain. Registered or inherited defaults may remain visible.")
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                model.refresh()
            }
        }
    }

    private var filteredRows: [FoundationDeveloperUserDefaultRow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.rows }
        return model.rows.filter {
            $0.key.localizedCaseInsensitiveContains(query)
                || $0.displayValue.localizedCaseInsensitiveContains(query)
                || $0.type.title.localizedCaseInsensitiveContains(query)
        }
    }

    private func userDefaultRow(_ row: FoundationDeveloperUserDefaultRow) -> some View {
        Button {
            editor = FoundationDeveloperUserDefaultsEditorContext(row: row)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: row.type.systemImage)
                    .foregroundStyle(theme.accent)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.key)
                        .font(.body.monospaced())
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)

                    Text(row.displayValue)
                        .font(.caption.monospaced())
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(row.type.title)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)

                    Text(row.isPersistent ? "Stored" : "Effective")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(row.isPersistent ? theme.success : theme.textMuted)
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy Key") {
                copyToPasteboard(row.key)
            }

            Button("Copy Value") {
                copyToPasteboard(
                    FoundationDeveloperUserDefaultsCodec.copyValue(row.value)
                )
            }

            Divider()

            Button("Edit") {
                editor = FoundationDeveloperUserDefaultsEditorContext(row: row)
            }

            if row.isPersistent {
                Button("Delete", role: .destructive) {
                    pendingDelete = row
                }
            }
        }
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        statusMessage = "Copied."
    }
}

@MainActor
private struct FoundationDeveloperUserDefaultsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.macAppTheme) private var theme

    private let originalRow: FoundationDeveloperUserDefaultRow?
    private let onSave: (String, Any) -> Void

    @State private var key: String
    @State private var type: FoundationDeveloperUserDefaultsValueType
    @State private var stringValue: String
    @State private var boolValue: Bool
    @State private var integerValue: String
    @State private var doubleValue: String
    @State private var dateValue: Date
    @State private var dataValue: String
    @State private var propertyListValue: String

    init(
        context: FoundationDeveloperUserDefaultsEditorContext,
        onSave: @escaping (String, Any) -> Void
    ) {
        let row = context.row
        originalRow = row
        self.onSave = onSave

        let initialType = row?.type ?? .string
        _key = State(initialValue: row?.key ?? "")
        _type = State(initialValue: initialType)
        _stringValue = State(initialValue: row?.value as? String ?? "")
        _boolValue = State(initialValue: (row?.value as? NSNumber)?.boolValue ?? false)
        _integerValue = State(
            initialValue: row.map {
                String(($0.value as? NSNumber)?.int64Value ?? 0)
            } ?? "0"
        )
        _doubleValue = State(
            initialValue: row.map {
                String(($0.value as? NSNumber)?.doubleValue ?? 0)
            } ?? "0"
        )
        _dateValue = State(initialValue: row?.value as? Date ?? .now)
        _dataValue = State(
            initialValue: (row?.value as? Data)?.base64EncodedString() ?? ""
        )
        _propertyListValue = State(
            initialValue: row.flatMap {
                FoundationDeveloperUserDefaultsCodec.propertyListText($0.value)
            } ?? FoundationDeveloperUserDefaultsCodec.emptyPropertyList(for: initialType)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Key") {
                    TextField("Key", text: $key)
                        .disabled(originalRow != nil)

                    if let originalRow {
                        LabeledContent(
                            "Source",
                            value: originalRow.isPersistent ? "Stored" : "Effective only"
                        )
                    }
                }

                Section("Value") {
                    Picker("Type", selection: $type) {
                        ForEach(FoundationDeveloperUserDefaultsValueType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .onChange(of: type) { _, newType in
                        if newType == .array || newType == .dictionary {
                            propertyListValue = FoundationDeveloperUserDefaultsCodec.emptyPropertyList(
                                for: newType
                            )
                        }
                    }

                    valueEditor
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(theme.destructive)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .foregroundStyle(theme.textPrimary)
            .tint(theme.accent)
            .navigationTitle(originalRow == nil ? "Add User Default" : "Edit User Default")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = parsedValue else { return }
                        onSave(normalizedKey, value)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(validationMessage != nil)
                }
            }
        }
        .frame(minWidth: 560, minHeight: 460)
    }

    @ViewBuilder
    private var valueEditor: some View {
        switch type {
        case .string:
            TextField("Value", text: $stringValue, axis: .vertical)
                .lineLimit(2...8)

        case .bool:
            Toggle("Value", isOn: $boolValue)

        case .integer:
            TextField("Integer", text: $integerValue)

        case .double:
            TextField("Double", text: $doubleValue)

        case .date:
            DatePicker("Date", selection: $dateValue)

        case .data:
            TextEditor(text: $dataValue)
                .font(.body.monospaced())
                .frame(minHeight: 140)
            Text("Base64-encoded Data.")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)

        case .array, .dictionary:
            TextEditor(text: $propertyListValue)
                .font(.caption.monospaced())
                .frame(minHeight: 220)
            Text("Edit as an XML property list. UserDefaults supports property-list values including strings, numbers, booleans, dates, data, arrays, and dictionaries.")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var normalizedKey: String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedValue: Any? {
        switch type {
        case .string:
            return stringValue
        case .bool:
            return boolValue
        case .integer:
            return Int(integerValue.trimmingCharacters(in: .whitespacesAndNewlines))
        case .double:
            return Double(doubleValue.trimmingCharacters(in: .whitespacesAndNewlines))
        case .date:
            return dateValue
        case .data:
            return Data(
                base64Encoded: dataValue.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        case .array, .dictionary:
            return try? FoundationDeveloperUserDefaultsCodec.propertyListValue(
                from: propertyListValue,
                expectedType: type
            )
        }
    }

    private var validationMessage: String? {
        if normalizedKey.isEmpty {
            return "Key is required."
        }

        switch type {
        case .integer:
            if Int(integerValue.trimmingCharacters(in: .whitespacesAndNewlines)) == nil {
                return "Enter a valid integer."
            }
        case .double:
            if Double(doubleValue.trimmingCharacters(in: .whitespacesAndNewlines)) == nil {
                return "Enter a valid double."
            }
        case .data:
            if Data(base64Encoded: dataValue.trimmingCharacters(in: .whitespacesAndNewlines)) == nil {
                return "Enter valid Base64 data."
            }
        case .array, .dictionary:
            do {
                _ = try FoundationDeveloperUserDefaultsCodec.propertyListValue(
                    from: propertyListValue,
                    expectedType: type
                )
            } catch {
                return error.localizedDescription
            }
        case .string, .bool, .date:
            break
        }

        return nil
    }
}
#endif
