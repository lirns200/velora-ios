import Foundation
import Combine
import NetworkExtension
import VPNCore

@MainActor
final class VPNController: ObservableObject {
    @Published private(set) var status: NEVPNStatus = .invalid
    @Published private(set) var busy = false
    @Published var error: String?
    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?

    var active: Bool { [.connected, .connecting, .reasserting, .disconnecting].contains(status) }
    var locked: Bool { busy || active }
    var statusText: String {
        switch status {
        case .connected: return "Туннель включён"
        case .connecting: return "Подключение…"
        case .reasserting: return "Восстановление связи…"
        case .disconnecting: return "Отключение…"
        default: return "Не подключено"
        }
    }

    init() {
        observer = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.status = self?.manager?.connection.status ?? .invalid }
        }
        Task { await reload() }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    func reload() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let id = try extensionID()
            let all = try await NETunnelProviderManager.loadAllFromPreferences()
            manager = all.first { ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == id }
            status = manager?.connection.status ?? .disconnected
        } catch { self.error = "Не удалось прочитать настройки VPN. Проверьте подпись Network Extension." }
    }

    func toggle(profile: ServerProfile?) async {
        guard !busy else { return }
        if active { manager?.connection.stopVPNTunnel(); return }
        guard let profile else { return }
        busy = true
        defer { busy = false }
        do {
            let m = manager ?? NETunnelProviderManager()
            let config = NETunnelProviderProtocol()
            config.providerBundleIdentifier = try extensionID()
            config.serverAddress = profile.host
            config.providerConfiguration = ["profileID": profile.id]
            config.disconnectOnSleep = false
            m.protocolConfiguration = config
            m.localizedDescription = "Velora VPN"
            m.isEnabled = true
            try await m.saveToPreferences()
            try await m.loadFromPreferences()
            manager = m
            try m.connection.startVPNTunnel()
            status = m.connection.status
        } catch {
            self.error = "Не удалось запустить VPN. Проверьте разрешение iOS и подпись приложения и расширения. \(error.localizedDescription)"
            status = manager?.connection.status ?? .disconnected
        }
    }

    private func extensionID() throws -> String {
        guard let id = Bundle.main.bundleIdentifier else { throw VPNError.invalidTunnel }
        return id + ".PacketTunnel"
    }
}
