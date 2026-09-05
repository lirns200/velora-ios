import Foundation

public struct ImportResult: Sendable {
    public let profiles: [ServerProfile]
    public let rejectedCount: Int
    public let duplicateCount: Int
}

public enum SubscriptionParser {
    public static let maximumBytes = 2 * 1024 * 1024
    public static func parse(_ input: String) throws -> ImportResult {
        guard input.utf8.count <= maximumBytes else { throw VPNError.tooLarge }
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.contains("://") {
            var encoded = text.filter { !$0.isWhitespace }.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
            if let data = Data(base64Encoded: encoded), let decoded = String(data: data, encoding: .utf8) { text = decoded }
        }
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        guard lines.count <= 1000 else { throw VPNError.tooLarge }
        var profiles: [ServerProfile] = []
        var seen = Set<String>()
        var rejected = 0
        var duplicates = 0
        for line in lines {
            do {
                let profile = try VLESSParser.parse(line)
                if seen.insert(profile.id).inserted { profiles.append(profile) } else { duplicates += 1 }
            } catch { rejected += 1 }
        }
        guard !profiles.isEmpty else { throw VPNError.invalidSubscription }
        return ImportResult(profiles: profiles, rejectedCount: rejected, duplicateCount: duplicates)
    }

    public static func validateURL(_ input: String) throws -> URL {
        guard let components = URLComponents(string: input), components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty, components.user == nil, components.password == nil,
              components.fragment == nil, let url = components.url else { throw VPNError.insecureURL }
        return url
    }
}
