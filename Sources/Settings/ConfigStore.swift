import SwiftUI
import ServiceManagement

@MainActor
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @AppStorage("behaviorMode") var behaviorMode: BehaviorMode = .hide
    @AppStorage("triggerModifier") var triggerModifier: String = "None"
    @AppStorage("excludedBundleIDs") var excludedBundleIDs: String = "com.apple.finder"
    
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    private init() {}
    
    func updateLaunchAtLoginStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
