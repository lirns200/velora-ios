import Foundation

public enum XrayConfiguration {
    public static func make(profile p: ServerProfile, fileDescriptor: Int32) throws -> Data {
        guard fileDescriptor >= 0 else { throw VPNError.invalidTunnel }
        var user: [String: Any] = ["id": p.userID, "encryption": "none"]
        if !p.flow.isEmpty { user["flow"] = p.flow }
        var stream: [String: Any] = ["network": p.transport, "security": p.security]
        if p.security == "reality" {
            stream["realitySettings"] = ["serverName": p.serverName, "fingerprint": p.fingerprint,
                "publicKey": p.publicKey, "shortId": p.shortID, "spiderX": "/"]
        } else {
            var tls: [String: Any] = ["serverName": p.serverName, "fingerprint": p.fingerprint, "allowInsecure": false]
            if !p.alpn.isEmpty { tls["alpn"] = p.alpn }
            stream["tlsSettings"] = tls
        }
        if p.transport == "ws" {
            var ws: [String: Any] = ["path": p.path]
            if !p.httpHost.isEmpty { ws["headers"] = ["Host": p.httpHost] }
            stream["wsSettings"] = ws
        }
        if p.transport == "grpc" { stream["grpcSettings"] = ["serviceName": p.serviceName, "multiMode": false] }
        let config: [String: Any] = [
            "log": ["loglevel": "none"],
            "env": ["xray.tun.fd": String(fileDescriptor)],
            "inbounds": [["tag": "tun", "protocol": "tun", "port": 0,
                          "settings": ["name": "utun", "mtu": 1280]]],
            "outbounds": [["tag": "proxy", "protocol": "vless", "streamSettings": stream,
                           "settings": ["vnext": [["address": p.host, "port": p.port, "users": [user]]]]]]
        ]
        return try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys])
    }
}
