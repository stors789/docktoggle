import SwiftUI

struct PermissionsGateView: View {
    @ObservedObject var permissionsManager = PermissionsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)

            HStack {
                Image(systemName: permissionsManager.accessibilityGranted
                    ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(permissionsManager.accessibilityGranted ? .green : .red)

                Text("Accessibility")

                Spacer()

                if permissionsManager.accessibilityGranted {
                    Text("Granted")
                        .foregroundColor(.secondary)
                } else {
                    Button("Grant") {
                        permissionsManager.requestAccessibility()
                    }
                }
            }

            HStack {
                Image(systemName: permissionsManager.inputMonitoringGranted
                    ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(permissionsManager.inputMonitoringGranted ? .green : .red)

                Text("Input Monitoring")

                Spacer()

                if permissionsManager.inputMonitoringGranted {
                    Text("Granted")
                        .foregroundColor(.secondary)
                } else {
                    Button("Grant") {
                        permissionsManager.requestInputMonitoring()
                    }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
}
