import Foundation

public enum VLESSParser {
    public static func parse(_ input: String) throws -> ServerProfile {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.utf8.count <= 16_384,
              let url = URLComponents(string: text), url.scheme?.lowercased() == "vless",
              let user = url.user, UUID(uuidString: user) != nil, url.password == nil,
              var host = url.host, !host.isEmpty,
              let port = url.port, (1...65535).contains(port), url.path.isEmpty || url.path == "/"
        else { throw VPNError.invalidLink }
        if host.hasPrefix("[") && host.hasSuffix("]") { host = String(host.dropFirst().dropLast()) }
        guard !host.contains(where: { $0.isWhitespace || $0.isNewline }) else { throw VPNError.invalidLink }
        let allowed: Set<String> = ["type", "security", "encryption", "sni", "fp", "pbk", "sid", "flow", "path", "host", "serviceName", "alpn", "headerType", "allowInsecure", "mode", "spx"]
        var q: [String: String] = [:]
        for item in url.queryItems ?? [] {
            guard allowed.contains(item.name), q[item.name] == nil else { throw VPNError.unsupportedOption }
            q[item.name] = item.value ?? ""
        }
        let transport = q["type"] == "raw" ? "tcp" : (q["type"] ?? "tcp")
        let security = q["security"] ?? "none"
        guard ["tcp", "ws", "grpc"].contains(transport), ["reality", "tls"].contains(security),
              [nil, "", "none"].contains(q["encryption"]),
              [nil, "", "none"].contains(q["headerType"]),
              [nil, "", "0", "false"].contains(q["allowInsecure"]),
              [nil, "", "gun"].contains(q["mode"])
        else { throw VPNError.unsupportedOption }
        let flow = q["flow"] ?? ""
        guard ["", "xtls-rprx-vision"].contains(flow), flow.isEmpty || transport == "tcp" else { throw VPNError.unsupportedOption }
        let serverName = q["sni"].flatMap { $0.isEmpty ? nil : $0 } ?? host
        let publicKey = q["pbk"] ?? ""
        let shortID = q["sid"] ?? ""
        if security == "reality" {
            guard transport == "tcp" else { throw VPNError.unsupportedOption }
            guard (q["alpn"] ?? "").isEmpty else { throw VPNError.unsupportedOption }
            guard publicKey.count == 43, publicKey.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }),
                  !(q["sni"] ?? "").isEmpty, shortID.count <= 16, shortID.count.isMultiple(of: 2),
                  shortID.allSatisfy({ $0.isHexDigit }) else { throw VPNError.invalidLink }
        }
        // Do not silently drop transport-specific fields which would change the connection.
        if transport == "tcp" && (!(q["host"] ?? "").isEmpty || !(q["serviceName"] ?? "").isEmpty || !(q["path"] ?? "").isEmpty) {
            throw VPNError.unsupportedOption
        }
        if transport != "grpc" && !(q["serviceName"] ?? "").isEmpty { throw VPNError.unsupportedOption }
        if transport != "grpc" && !(q["mode"] ?? "").isEmpty { throw VPNError.unsupportedOption }
        if transport == "grpc" && (!(q["path"] ?? "").isEmpty || !(q["host"] ?? "").isEmpty) { throw VPNError.unsupportedOption }
        if !(q["spx"] ?? "").isEmpty && q["spx"] != "/" { throw VPNError.unsupportedOption }
        let name = (url.fragment?.isEmpty == false ? url.fragment : nil) ?? host
        return ServerProfile(
            id: ServerProfile.identity(text), name: String(name.prefix(128)), host: host, port: port,
            userID: user.lowercased(), transport: transport, security: security, serverName: serverName,
            fingerprint: q["fp"].flatMap { $0.isEmpty ? nil : $0 } ?? "chrome", publicKey: publicKey,
            shortID: shortID, flow: flow, path: q["path"] ?? "/", httpHost: q["host"] ?? "",
            serviceName: q["serviceName"] ?? "", alpn: (q["alpn"] ?? "").split(separator: ",").map(String.init)
        )
    }
}
