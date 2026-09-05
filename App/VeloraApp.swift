import SwiftUI

@main
struct VeloraApp: App {
    @StateObject private var profiles = ProfileStore()
    @StateObject private var vpn = VPNController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profiles)
                .environmentObject(vpn)
                .preferredColorScheme(.dark)
                .tint(Theme.mint)
        }
    }
}
