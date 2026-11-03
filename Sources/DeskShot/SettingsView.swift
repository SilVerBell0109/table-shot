import SwiftUI
import AppKit
import DeskShotKit

/// 저장 폴더 선택 + 핫키(고정) 표시.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("저장 폴더") {
                HStack {
                    Text(model.saveFolderURL.path)
                        .lineLimit(1).truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("변경…") { model.chooseFolder() }
                }
            }
            Section("단축키") {
                LabeledContent("캡처", value: "⌘⇧2")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 180)
    }
}

/// SettingsStore를 SwiftUI에 노출하는 관찰 가능한 래퍼.
@MainActor
final class SettingsModel: ObservableObject {
    @Published private(set) var saveFolderURL: URL
    let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
        self.saveFolderURL = store.saveFolderURL
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = saveFolderURL
        if panel.runModal() == .OK, let url = panel.url {
            store.saveFolderURL = url
            saveFolderURL = url
        }
    }
}
