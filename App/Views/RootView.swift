import SwiftUI
import NetworkExtension
import VPNCore

enum Theme {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.10)
    static let card = Color(red: 0.075, green: 0.105, blue: 0.16)
    static let mint = Color(red: 0.40, green: 0.94, blue: 0.80)
    static let secondary = Color(red: 0.57, green: 0.64, blue: 0.74)
}

struct RootView: View {
    @EnvironmentObject private var profiles: ProfileStore
    @EnvironmentObject private var vpn: VPNController
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var showImport = false

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { connection }
                .tabItem { Label("Подключение", systemImage: "power") }.tag(0)
            NavigationStack { ServersView(showImport: $showImport) }
                .tabItem { Label("Серверы", systemImage: "server.rack") }.tag(1)
            NavigationStack { settings }
                .tabItem { Label("Настройки", systemImage: "slider.horizontal.3") }.tag(2)
        }
        .sheet(isPresented: $showImport) { ImportView().environmentObject(profiles).environmentObject(vpn) }
        .alert("Не удалось выполнить действие", isPresented: Binding(
            get: { profiles.error != nil || vpn.error != nil },
            set: { if !$0 { profiles.error = nil; vpn.error = nil } }
        ), actions: { Button("Понятно", role: .cancel) { profiles.error = nil; vpn.error = nil } },
            message: { Text(profiles.error ?? vpn.error ?? "") })
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await vpn.reload() } } }
    }

    private var connection: some View {
        ScrollView {
            VStack(spacing: 28) {
                HStack(spacing: 10) {
                    Image(systemName: "shield.lefthalf.filled").font(.title2).foregroundStyle(Theme.mint)
                    Text("velora").font(.system(size: 29, weight: .semibold, design: .rounded)).tracking(-1)
                    Spacer()
                    Text("VPN").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Theme.secondary)
                }
                .padding(.top, 16)

                VStack(spacing: 9) {
                    Text(vpn.statusText).font(.title2.weight(.semibold))
                    Text(vpn.status == .connected ? "Трафик направлен через выбранный сервер" : "Твоё подключение. Под твоим контролем.")
                        .font(.subheadline).foregroundStyle(Theme.secondary).multilineTextAlignment(.center)
                }

                Button {
                    if !vpn.active && profiles.state.selected == nil { showImport = true }
                    else { Task { await vpn.toggle(profile: profiles.state.selected) } }
                } label: {
                    ZStack {
                        Circle().stroke(Theme.mint.opacity(0.07), lineWidth: 1).frame(width: 242, height: 242)
                        Circle().stroke(Theme.mint.opacity(0.12), lineWidth: 1).frame(width: 212, height: 212)
                        Circle().fill(Theme.card).frame(width: 180, height: 180)
                            .overlay(Circle().stroke(Theme.mint.opacity(vpn.status == .connected ? 1 : 0.35), lineWidth: 2))
                            .shadow(color: Theme.mint.opacity(vpn.status == .connected ? 0.18 : 0.05), radius: 28)
                        VStack(spacing: 12) {
                            if vpn.busy || vpn.status == .connecting || vpn.status == .disconnecting {
                                ProgressView().controlSize(.large).tint(Theme.mint)
                            } else {
                                Image(systemName: "power").font(.system(size: 46, weight: .light)).foregroundStyle(Theme.mint)
                            }
                            Text(vpn.active ? "Отключить" : "Подключить").font(.subheadline.weight(.medium)).foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .disabled(vpn.busy || vpn.status == .disconnecting || (!vpn.active && (profiles.busy || !profiles.storageAvailable)))
                .accessibilityLabel(vpn.active ? "Отключить VPN" : "Подключить VPN")

                Button { tab = 1 } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "network").font(.title2).foregroundStyle(Theme.mint)
                            .frame(width: 44, height: 44).background(Theme.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("ВЫБРАННЫЙ СЕРВЕР").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(Theme.secondary)
                            Text(profiles.state.selected?.name ?? "Добавь первое подключение").font(.headline).foregroundStyle(.white).lineLimit(2)
                            if let profile = profiles.state.selected {
                                Text(profile.protocolLabel).font(.caption).foregroundStyle(Theme.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
                    }
                    .padding(18).background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
                }.buttonStyle(.plain)

                if profiles.state.profiles.isEmpty {
                    Button { showImport = true } label: { Label("Добавить ссылку или подписку", systemImage: "plus") }
                        .disabled(vpn.locked || !profiles.storageAvailable)
                }
                Label("Без регистрации и встроенных серверов", systemImage: "lock")
                    .font(.caption).foregroundStyle(Theme.secondary)
                if let notice = profiles.notice {
                    Text(notice).font(.caption).foregroundStyle(Theme.secondary).multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .background(Theme.background).toolbar(.hidden, for: .navigationBar)
    }

    private var settings: some View {
        List {
            Section("Подключение") {
                LabeledContent("Ядро", value: "Xray")
                LabeledContent("Система", value: "iOS 17+")
                Text("Поддерживаются VLESS TCP/Reality, TCP/TLS, WebSocket/TLS и gRPC/TLS. Сервер или подписку нужно добавить самостоятельно.")
                    .font(.footnote).foregroundStyle(Theme.secondary)
            }
            Section("Приватность") {
                Label("Профили хранятся в Keychain", systemImage: "key.fill")
                Label("Без аналитики и рекламы", systemImage: "hand.raised.fill")
                Text("Подписки загружаются только по HTTPS. При обновлении приложение обращается к поставщику подписки. DNS 1.1.1.1 / 1.0.0.1 направляется через туннель. Проверка TLS-сертификатов всегда включена.")
                    .font(.footnote).foregroundStyle(Theme.secondary)
            }
            Section("О приложении") {
                LabeledContent("Velora", value: "1.0.0")
                Text("Клиент для твоих серверов. Статус подключения показывает состояние системного туннеля; доступность интернета зависит от сервера. После отключения VPN действует обычное подключение iOS.")
                    .font(.footnote).foregroundStyle(Theme.secondary)
                Link("Исходный код Xray", destination: URL(string: "https://github.com/XTLS/Xray-core")!)
                Link("libXray · MIT License", destination: URL(string: "https://github.com/XTLS/libXray")!)
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background).navigationTitle("Настройки")
    }
}
