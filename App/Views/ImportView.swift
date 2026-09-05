import SwiftUI

struct ImportView: View {
    @EnvironmentObject private var profiles: ProfileStore
    @EnvironmentObject private var vpn: VPNController
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название подписки (необязательно)", text: $name)
                        .textInputAutocapitalization(.sentences)
                    TextEditor(text: $text)
                        .frame(minHeight: 170).font(.body.monospaced())
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityLabel("VLESS-ссылка или HTTPS-подписка")
                    PasteButton(payloadType: String.self) { values in
                        if let value = values.first { text = value }
                    }.disabled(profiles.busy)
                } header: { Text("Ссылка или подписка") } footer: {
                    Text("Вставь vless://… или https://… Можно добавить несколько VLESS-ссылок, каждую с новой строки. Зашифрованные happ://crypto-ссылки не поддерживаются.")
                }
                Section {
                    Button {
                        Task { if await profiles.importText(text, name: name.trimmingCharacters(in: .whitespacesAndNewlines)) { dismiss() } }
                    } label: {
                        HStack {
                            Spacer()
                            if profiles.busy { ProgressView() } else { Text("Добавить подключение").fontWeight(.semibold) }
                            Spacer()
                        }
                    }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || profiles.busy || vpn.locked || !profiles.storageAvailable)
                }
                if let error = profiles.error { Section { Text(error).font(.footnote).foregroundStyle(.red) } }
            }
            .navigationTitle("Новое подключение").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() }.disabled(profiles.busy) } }
            .interactiveDismissDisabled(profiles.busy)
        }
    }
}
