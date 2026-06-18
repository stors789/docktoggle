import SwiftUI
import ServiceManagement

@MainActor
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @AppStorage("behaviorMode") var behaviorMode: BehaviorMode = .hide
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("triggerModifier") var triggerModifier: String = "None"
    @AppStorage("excludedBundleIDs") var excludedBundleIDs: String = "com.apple.finder"

    private init() {}
}
