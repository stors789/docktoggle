import Foundation

enum BehaviorMode: String, Codable, CaseIterable {
    case hide
    case minimize

    var displayName: String {
        switch self {
        case .hide:    "Hide Application"
        case .minimize: "Minimize Front Window"
        }
    }
}
