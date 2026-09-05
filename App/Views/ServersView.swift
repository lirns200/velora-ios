import SwiftUI
import VPNCore

struct ServersView: View {
    @EnvironmentObject private var profiles: ProfileStore
    @EnvironmentObject private var vpn: VPNController
    @Binding var showImport: Bool
    @State private var pendingDeletion: VPNCore.Subscription?
    private var locked: Bool { vpn.locked || profiles.busy || !profiles.storageAvailable }

    var body: some View {
        List {
            if vpn.active {
                Text("Отключи VPN, чтобы сменить сервер или обновить подписку.")
                    .font(.footnote).foregroundStyle(Theme.secondary)
            }
            if profiles.state.profiles.isEmpty {
                ContentUnavailableView {
                    Label("Здесь будут твои серверы", systemImage: "network")
                } description: {
                    Text("Добавь VLESS-ссылку или HTTPS-подписку от своего провайдера.")
                } actions: {
                    Button("Добавить подключение") { showImport = true }.disabled(locked)
                }
                .listRowBackground(Color.clear)
            }
            if !profiles.state.localProfiles.isEmpty {
                Section("Мои серверы") {
                    ForEach(profiles.state.localProfiles) { profile in
                        row(profile)
                            .swipeActions {
                                Button("Удалить", role: .destructive) { profiles.deleteLocal(profile) }.disabled(locked)
                            }
                    }
                }
            }
            ForEach(profiles.state.subscriptions) { subscription in
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(subscription.name).font(.headline)
                            if let date = subscription.updatedAt {
                                Text("Обновлено \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(Theme.secondary)
                            }
                        }
                        Spacer()
                        Button { Task { await profiles.refresh(subscription) } } label: { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(.borderless).disabled(locked).accessibilityLabel("Обновить \(subscription.name)")
                        Button(role: .destructive) { pendingDeletion = subscription } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless).disabled(locked).accessibilityLabel("Удалить подписку \(subscription.name)")
                    }
                    ForEach(subscription.profiles) { row($0) }
                } header: { Text("Подписка · \(subscription.profiles.count)") }
            }
            if let notice = profiles.notice { Text(notice).font(.footnote).foregroundStyle(Theme.secondary) }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle("Серверы")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if profiles.busy { ProgressView() }
                else { Button { showImport = true } label: { Image(systemName: "plus") }.disabled(locked).accessibilityLabel("Добавить подключение") }
            }
        }
        .confirmationDialog("Удалить подписку и её серверы?", isPresented: Binding(
            get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("Удалить подписку", role: .destructive) {
                if let subscription = pendingDeletion, !locked { profiles.deleteSubscription(subscription) }
                pendingDeletion = nil
            }
        }
    }

    private func row(_ profile: ServerProfile) -> some View {
        Button { profiles.select(profile) } label: {
            HStack(spacing: 12) {
                Image(systemName: profiles.state.selectedID == profile.id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(profiles.state.selectedID == profile.id ? Theme.mint : Theme.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.name).font(.body.weight(.medium)).foregroundStyle(.white).lineLimit(2)
                    Text(profile.protocolLabel).font(.caption).foregroundStyle(Theme.secondary)
                    Text("\(profile.host):\(profile.port)").font(.caption2.monospaced()).foregroundStyle(Theme.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
        }.disabled(locked).listRowBackground(Theme.card)
    }
}
