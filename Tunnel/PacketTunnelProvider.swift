import NetworkExtension
import Foundation
import Darwin
import VPNCore

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let lifecycle = DispatchQueue(label: "app.velora.tunnel.lifecycle")
    private var generation = 0
    private var running = false
    private var pendingStart: ((Error?) -> Void)?

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        lifecycle.async {
            guard !self.running, self.pendingStart == nil else { completionHandler(VPNError.invalidTunnel); return }
            self.generation += 1
            let token = self.generation
            self.pendingStart = completionHandler
            do {
                let library = try SecureLibrary.load()
                let config = self.protocolConfiguration as? NETunnelProviderProtocol
                guard let id = config?.providerConfiguration?["profileID"] as? String,
                      let profile = library.profiles.first(where: { $0.id == id }) else { throw VPNError.invalidLink }
                let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
                settings.mtu = 1280
                let ipv4 = NEIPv4Settings(addresses: ["192.0.2.2"], subnetMasks: ["255.255.255.252"])
                ipv4.includedRoutes = [NEIPv4Route.default()]
                settings.ipv4Settings = ipv4
                let ipv6 = NEIPv6Settings(addresses: ["fd74:656c:6f72::2"], networkPrefixLengths: [64])
                ipv6.includedRoutes = [NEIPv6Route.default()]
                settings.ipv6Settings = ipv6
                let dns = NEDNSSettings(servers: ["1.1.1.1", "1.0.0.1"])
                dns.matchDomains = [""]
                settings.dnsSettings = dns
                self.setTunnelNetworkSettings(settings) { error in
                    self.lifecycle.async {
                        guard token == self.generation else { return }
                        do {
                            if let error { throw error }
                            let fd = try Self.tunnelDescriptor()
                            let data = try XrayConfiguration.make(profile: profile, fileDescriptor: fd)
                            try XrayBridge.invoke("runXray", payload: ["xrayJson": String(decoding: data, as: UTF8.self)])
                            self.running = true
                            self.finishStart(nil)
                        } catch {
                            try? XrayBridge.invoke("stopXray")
                            self.finishStart(error)
                        }
                    }
                }
            } catch { self.finishStart(error) }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        lifecycle.async {
            self.generation += 1
            self.finishStart(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
            if self.running { try? XrayBridge.invoke("stopXray") }
            self.running = false
            completionHandler()
        }
    }

    private func finishStart(_ error: Error?) {
        let completion = pendingStart
        pendingStart = nil
        completion?(error)
    }

    private static func tunnelDescriptor() throws -> Int32 {
        // libXray/Xray-core's documented iOS integration: find the NE-owned utun socket.
        // Reject ambiguity instead of attaching to an arbitrary interface.
        var matches: [Int32] = []
        for fd: Int32 in 0..<getdtablesize() {
            var buffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))
            var size = socklen_t(buffer.count)
            let result = buffer.withUnsafeMutableBytes { getsockopt(fd, 2, 2, $0.baseAddress, &size) }
            if result == 0, buffer.starts(with: "utun".utf8CString.dropLast()) { matches.append(fd) }
        }
        guard matches.count == 1, let descriptor = matches.first else { throw VPNError.invalidTunnel }
        return descriptor
    }
}
