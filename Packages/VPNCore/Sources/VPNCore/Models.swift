import Foundation
import CryptoKit

public struct ServerProfile: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let host: String
    public let port: Int
    public let userID: String
    public let transport: String
    public let security: String
    public let serverName: String
    public let fingerprint: String
    public let publicKey: String
    public let shortID: String
    public let flow: String
    public let path: String
    public let httpHost: String
    public let serviceName: String
    public let alpn: [String]

    public var protocolLabel: String {
        security == "reality" ? "VLESS · REALITY" : "VLESS · TLS · \(transport.uppercased())"
    }

    static func identity(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

public struct Subscription: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var url: String
    public var profiles: [ServerProfile]
    public var updatedAt: Date?

    public init(id: UUID = UUID(), name: String, url: String, profiles: [ServerProfile], updatedAt: Date? = nil) {
        self.id = id; self.name = name; self.url = url; self.profiles = profiles; self.updatedAt = updatedAt
    }
}

public struct LibraryState: Codable, Equatable, Sendable {
    public var localProfiles: [ServerProfile] = []
    public var subscriptions: [Subscription] = []
    public var selectedID: String?

    public init() {}
    public var profiles: [ServerProfile] {
        var seen = Set<String>()
        return (localProfiles + subscriptions.flatMap(\.profiles)).filter { seen.insert($0.id).inserted }
    }
    public var selected: ServerProfile? { profiles.first { $0.id == selectedID } }

    public mutating func repairSelection() {
        if selected == nil { selectedID = profiles.first?.id }
    }

    public mutating func replaceSubscription(_ id: UUID, profiles: [ServerProfile], date: Date) throws {
        guard !profiles.isEmpty, let index = subscriptions.firstIndex(where: { $0.id == id }) else {
            throw VPNError.invalidSubscription
        }
        subscriptions[index].profiles = profiles
        subscriptions[index].updatedAt = date
        repairSelection()
    }
}

public enum VPNError: LocalizedError {
    case invalidLink, unsupportedOption, invalidSubscription, tooLarge, insecureURL, invalidTunnel
    public var errorDescription: String? {
        switch self {
        case .invalidLink: return "Некорректная ссылка VLESS. Проверьте адрес, UUID и параметры подключения."
        case .unsupportedOption: return "Параметры ссылки не поддерживаются. Доступны TCP/Reality, TCP/TLS, WebSocket/TLS и gRPC/TLS."
        case .invalidSubscription: return "В подписке нет поддерживаемых серверов. Сохранённые профили не изменены."
        case .tooLarge: return "Подписка слишком большая: максимум 2 МБ и 1000 серверов."
        case .insecureURL: return "Подписка должна использовать HTTPS без логина и пароля в адресе."
        case .invalidTunnel: return "Не удалось получить системный VPN-туннель."
        }
    }
}
