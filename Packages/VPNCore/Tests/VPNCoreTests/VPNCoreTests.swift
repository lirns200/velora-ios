import XCTest
@testable import VPNCore

final class VPNCoreTests: XCTestCase {
    let id = "11111111-1111-4111-8111-111111111111"
    var reality: String {
        "vless://\(id)@vpn.example.com:443?type=tcp&security=reality&pbk=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&sni=www.example.com&sid=abcd&fp=chrome&flow=xtls-rprx-vision#My%20server"
    }

    func testRealityRetainsAuthenticationAndName() throws {
        let p = try VLESSParser.parse(reality)
        XCTAssertEqual(p.name, "My server")
        XCTAssertEqual(p.host, "vpn.example.com")
        XCTAssertEqual(p.shortID, "abcd")
        XCTAssertEqual(p.flow, "xtls-rprx-vision")
        XCTAssertEqual(p.userID, id)
    }

    func testIPv6AndEscapedWebSocketPath() throws {
        let p = try VLESSParser.parse("vless://\(id)@[2001:db8::1]:8443?type=ws&security=tls&sni=example.com&path=%2Fsocket%3Fed%3D2048&host=cdn.example.com")
        XCTAssertEqual(p.host, "2001:db8::1")
        XCTAssertEqual(p.path, "/socket?ed=2048")
        XCTAssertEqual(p.port, 8443)
    }

    func testRejectsMissingRealityKeyAndDuplicateParameters() {
        XCTAssertThrowsError(try VLESSParser.parse("vless://\(id)@example.com:443?security=reality&sni=example.com"))
        XCTAssertThrowsError(try VLESSParser.parse(reality.replacingOccurrences(of: "#My%20server", with: "&security=tls")))
    }

    func testRejectsUnsafeOrUnsupportedOptions() {
        for query in ["security=none", "security=tls&type=xhttp", "security=tls&allowInsecure=1", "security=tls&encryption=other", "security=tls&type=ws&flow=xtls-rprx-vision", "security=tls&type=grpc&mode=multi", "security=tls&unknown=1"] {
            XCTAssertThrowsError(try VLESSParser.parse("vless://\(id)@example.com:443?\(query)"), query)
        }
    }

    func testBase64SubscriptionDeduplicatesAndCountsRejectedRows() throws {
        let text = reality + "\n" + reality + "\nvless://broken\nvmess://unsupported"
        let result = try SubscriptionParser.parse(Data(text.utf8).base64EncodedString())
        XCTAssertEqual(result.profiles.count, 1)
        XCTAssertEqual(result.rejectedCount, 2)
        XCTAssertEqual(result.duplicateCount, 1)
    }

    func testInvalidSubscriptionDoesNotProduceReplacement() {
        XCTAssertThrowsError(try SubscriptionParser.parse("<html>Error</html>"))
        XCTAssertThrowsError(try SubscriptionParser.parse("vmess://abc\nvless://broken"))
        XCTAssertThrowsError(try SubscriptionParser.parse(String(repeating: "x", count: 2_097_153)))
    }

    func testSubscriptionURLRejectsInsecureOrCredentialURLs() throws {
        XCTAssertThrowsError(try SubscriptionParser.validateURL("http://example.com/sub"))
        XCTAssertThrowsError(try SubscriptionParser.validateURL("https://user:pass@example.com/sub"))
        XCTAssertThrowsError(try SubscriptionParser.validateURL("https://example.com/sub#fragment"))
        XCTAssertEqual(try SubscriptionParser.validateURL("https://example.com/sub?token=abc").host, "example.com")
    }

    func testRejectsRealityOptionsThatWouldOtherwiseBeDropped() {
        XCTAssertThrowsError(try VLESSParser.parse(reality.replacingOccurrences(of: "#My%20server", with: "&alpn=h2")))
        XCTAssertThrowsError(try VLESSParser.parse(reality.replacingOccurrences(of: "#My%20server", with: "&mode=gun")))
    }

    func testRefreshPreservesUnrelatedProfilesAndSelection() throws {
        let a = try VLESSParser.parse(reality)
        let b = try VLESSParser.parse(reality.replacingOccurrences(of: "vpn.example.com", with: "other.example.com"))
        let sid = UUID()
        var state = LibraryState()
        state.localProfiles = [b]
        state.subscriptions = [Subscription(id: sid, name: "Work", url: "https://example.com/sub", profiles: [a])]
        state.selectedID = b.id
        try state.replaceSubscription(sid, profiles: [a], date: Date())
        XCTAssertEqual(state.selectedID, b.id)
        XCTAssertEqual(state.localProfiles, [b])
        XCTAssertThrowsError(try state.replaceSubscription(sid, profiles: [], date: Date()))
        XCTAssertEqual(state.subscriptions[0].profiles, [a])
    }

    func testTunnelConfigUsesNativeFDAndNoDirectFallback() throws {
        let p = try VLESSParser.parse(reality)
        let data = try XrayConfiguration.make(profile: p, fileDescriptor: 42)
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let env = try XCTUnwrap(config["env"] as? [String: String])
        XCTAssertEqual(env["xray.tun.fd"], "42")
        let inbounds = try XCTUnwrap(config["inbounds"] as? [[String: Any]])
        XCTAssertEqual(inbounds.first?["protocol"] as? String, "tun")
        let outbounds = try XCTUnwrap(config["outbounds"] as? [[String: Any]])
        XCTAssertEqual(outbounds.count, 1)
        XCTAssertEqual(outbounds.first?["protocol"] as? String, "vless")
        let stream = try XCTUnwrap(outbounds[0]["streamSettings"] as? [String: Any])
        let reality = try XCTUnwrap(stream["realitySettings"] as? [String: Any])
        XCTAssertEqual(reality["serverName"] as? String, "www.example.com")
        XCTAssertEqual(reality["shortId"] as? String, "abcd")
        XCTAssertThrowsError(try XrayConfiguration.make(profile: p, fileDescriptor: -1))
    }

    func testTLSCannotDisableCertificateVerification() throws {
        let p = try VLESSParser.parse("vless://\(id)@example.com:443?security=tls&type=ws&path=%2Fvpn")
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: XrayConfiguration.make(profile: p, fileDescriptor: 1)) as? [String: Any])
        let outbound = try XCTUnwrap((config["outbounds"] as? [[String: Any]])?.first)
        let stream = try XCTUnwrap(outbound["streamSettings"] as? [String: Any])
        XCTAssertEqual((stream["tlsSettings"] as? [String: Any])?["allowInsecure"] as? Bool, false)
    }
}
