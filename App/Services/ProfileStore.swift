import Foundation
import Combine
import VPNCore

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var state = LibraryState()
    @Published private(set) var busy = false
    @Published private(set) var storageAvailable = true
    @Published var error: String?
    @Published var notice: String?

    init() {
        do { state = try SecureLibrary.load(); state.repairSelection() }
        catch {
            storageAvailable = false
            self.error = "Не удалось прочитать профили. \(error.localizedDescription)"
        }
    }

    private func commit(_ next: LibraryState) throws {
        guard storageAvailable else { throw SecureLibrary.StorageError.configuration }
        try SecureLibrary.save(next)
        state = next
    }

    func select(_ profile: ServerProfile) {
        do {
            var next = state; next.selectedID = profile.id
            try commit(next)
        } catch { self.error = error.localizedDescription }
    }

    func importText(_ value: String, name: String) async -> Bool {
        guard !busy, storageAvailable else { return false }
        busy = true
        defer { busy = false }
        do {
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            var next = state
            let result: ImportResult
            if text.lowercased().hasPrefix("https://") || text.lowercased().hasPrefix("http://") {
                let url = try SubscriptionParser.validateURL(text)
                result = try await SubscriptionClient.fetch(text)
                if let subscription = next.subscriptions.first(where: { $0.url == url.absoluteString }) {
                    try next.replaceSubscription(subscription.id, profiles: result.profiles, date: Date())
                } else {
                    next.subscriptions.append(VPNCore.Subscription(name: name.isEmpty ? (url.host ?? "Подписка") : String(name.prefix(80)),
                        url: url.absoluteString, profiles: result.profiles, updatedAt: Date()))
                }
            } else {
                result = try SubscriptionParser.parse(text)
                var seen = Set(next.localProfiles.map(\.id))
                next.localProfiles += result.profiles.filter { seen.insert($0.id).inserted }
            }
            next.repairSelection()
            try commit(next)
            notice = "Обработано серверов: \(result.profiles.count). Пропущено неподдерживаемых: \(result.rejectedCount), повторов: \(result.duplicateCount)."
            return true
        } catch {
            self.error = Self.safeMessage(error)
            return false
        }
    }

    func refresh(_ subscription: VPNCore.Subscription) async {
        guard !busy, storageAvailable else { return }
        busy = true
        defer { busy = false }
        do {
            let result = try await SubscriptionClient.fetch(subscription.url)
            var next = state
            try next.replaceSubscription(subscription.id, profiles: result.profiles, date: Date())
            try commit(next)
            notice = "Подписка обновлена. Серверов: \(result.profiles.count), пропущено: \(result.rejectedCount)."
        } catch { self.error = Self.safeMessage(error) }
    }

    func deleteLocal(_ profile: ServerProfile) {
        edit { $0.localProfiles.removeAll { $0.id == profile.id } }
    }
    func deleteSubscription(_ subscription: VPNCore.Subscription) {
        edit { $0.subscriptions.removeAll { $0.id == subscription.id } }
    }
    private func edit(_ action: (inout LibraryState) -> Void) {
        do {
            var next = state; action(&next); next.repairSelection()
            try commit(next)
        } catch { self.error = error.localizedDescription }
    }
    private static func safeMessage(_ error: Error) -> String {
        // URLSession error descriptions can contain a credential-bearing subscription URL.
        if error is URLError { return "Не удалось загрузить подписку. Проверьте интернет и доступность сервера." }
        return error.localizedDescription
    }
}
