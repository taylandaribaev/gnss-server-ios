import CoreLocation
import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var coordinator: ServerCoordinator
    @Environment(\.openURL) private var openURL
    @State private var locationPermissionAlert: LocationPermissionAlert?
    @State private var includePreciseCoordinatesInLogExport = false
    @State private var toastMessage: String?
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var shareItem: ShareItem?

    private static let privacyPolicyURL = URL(string: "https://github.com/taylandaribaev/gnss-server-ios/blob/main/PRIVACY.md")!

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("section.server")) {
                    LabeledContent(L10n.tr("server.state"), value: coordinator.statusText)
                    SelectableValueRow(label: L10n.tr("server.tcpPort"), value: "8887")
                    LabeledContent(L10n.tr("server.clients"), value: "\(coordinator.connectedClientCount)")

                    if coordinator.localIPAddresses.isEmpty {
                        LabeledContent(L10n.tr("server.ipAddress"), value: L10n.tr("server.ipNotFound"))
                    } else {
                        ForEach(Array(coordinator.localIPAddresses.enumerated()), id: \.element) { index, address in
                            SelectableValueRow(
                                label: index == 0 ? L10n.tr("server.ipAddress") : L10n.tr("server.otherIp"),
                                value: address
                            )
                        }
                    }

                    if let error = coordinator.errorText {
                        Label(error, systemImage: "exclamationmark.triangle")
                    }

                    Button(
                        coordinator.isRunning ? L10n.tr("server.stop") : L10n.tr("server.start"),
                        role: coordinator.isRunning ? .destructive : nil
                    ) {
                        handleServerButton()
                    }
                }

                Section(L10n.tr("section.location")) {
                    LabeledContent(L10n.tr("location.permission"), value: coordinator.locationAuthorizationText)
                    LabeledContent(L10n.tr("location.precision"), value: coordinator.precisionText)

                    if let location = coordinator.lastLocation {
                        SelectableValueRow(
                            label: L10n.tr("location.coordinates"),
                            value: String(format: "%.6f, %.6f", location.latitude, location.longitude)
                        )
                        LabeledContent(
                            L10n.tr("location.accuracy"),
                            value: String(format: L10n.tr("location.accuracyValue"), location.accuracy)
                        )
                    } else {
                        Text(L10n.tr("location.noCoordinates"))
                            .foregroundStyle(.secondary)
                    }

                    if coordinator.shouldShowLocationPermissionButton {
                        Button(L10n.tr("location.requestPermissions")) {
                            handlePermissionButton()
                        }
                    }
                }
                
                Section {
                    NavigationLink {
                        DiagnosticsView(
                            diagnostics: diagnostics,
                            includePreciseCoordinatesInLogExport: $includePreciseCoordinatesInLogExport,
                            copyBriefDiagnostics: copyBriefDiagnostics,
                            shareLogFile: shareLogFile,
                            clearLogs: clearLogs
                        )
                    } label: {
                        DiagnosticsLinkLabel(
                            summary: diagnosticsSummaryText,
                            warningCount: diagnosticsWarningCount
                        )
                    }

                    NavigationLink {
                        SetupGuideView()
                    } label: {
                        Label(L10n.tr("setup.linkTitle"), systemImage: "questionmark.circle")
                    }
                }

                Section(L10n.tr("section.background")) {
                    Text(L10n.tr("background.description"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section(L10n.tr("section.about")) {
                    LabeledContent(L10n.tr("about.version"), value: appVersionText)

                    Link(destination: Self.privacyPolicyURL) {
                        Label(L10n.tr("about.privacyPolicy"), systemImage: "hand.raised")
                    }
                }
            }
            .navigationTitle(L10n.tr("app.title"))
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    ToastView(message: toastMessage)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(activityItems: [item.url])
            }
            .alert(item: $locationPermissionAlert) { alert in
                switch alert {
                case .denied:
                    return Alert(
                        title: Text(L10n.tr("alert.locationDenied.title")),
                        message: Text(L10n.tr("alert.locationDenied.message")),
                        primaryButton: .default(Text(L10n.tr("common.settings"))) {
                            openAppSettings()
                        },
                        secondaryButton: .cancel(Text(L10n.tr("common.cancel")))
                    )
                case .whenInUse:
                    return Alert(
                        title: Text(L10n.tr("alert.whenInUse.title")),
                        message: Text(L10n.tr("alert.whenInUse.message")),
                        primaryButton: .default(Text(L10n.tr("common.settings"))) {
                            openAppSettings()
                        },
                        secondaryButton: .default(Text(L10n.tr("common.requestAgain"))) {
                            coordinator.requestPermissions()
                        }
                    )
                case .restricted:
                    return Alert(
                        title: Text(L10n.tr("alert.locationRestricted.title")),
                        message: Text(L10n.tr("alert.locationRestricted.message")),
                        primaryButton: .default(Text(L10n.tr("common.settings"))) {
                            openAppSettings()
                        },
                        secondaryButton: .cancel(Text(L10n.tr("common.cancel")))
                    )
                }
            }
        }
    }

    private func handleServerButton() {
        if coordinator.isRunning {
            coordinator.stop()
            return
        }

        switch coordinator.locationAuthorizationStatus {
        case .denied:
            locationPermissionAlert = .denied
        case .restricted:
            locationPermissionAlert = .restricted
        case .authorizedWhenInUse:
            locationPermissionAlert = .whenInUse
        default:
            coordinator.start()
        }
    }

    private func handlePermissionButton() {
        switch coordinator.locationAuthorizationStatus {
        case .denied:
            locationPermissionAlert = .denied
        case .restricted:
            locationPermissionAlert = .restricted
        case .authorizedWhenInUse:
            locationPermissionAlert = .whenInUse
        default:
            coordinator.requestPermissions()
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func copyBriefDiagnostics() {
        UIPasteboard.general.string = LogExportService.makeBriefDiagnostics(
            diagnostics: diagnostics,
            context: exportContext
        )
        showToast(L10n.tr("toast.briefDiagnosticsCopied"))
        AppLogger.shared.info(.export, "Brief diagnostics copied")
    }

    private func shareLogFile() {
        do {
            let url = try LogExportService.exportLogFile(context: exportContext)
            shareItem = ShareItem(url: url)
            showToast(L10n.tr("toast.logFilePrepared"))
        } catch {
            showToast(L10n.tr("toast.logFileFailed"))
            AppLogger.shared.error(.export, "Log export failed: \(error.localizedDescription)")
        }
    }

    private func clearLogs() {
        AppLogger.shared.clear()
        showToast(L10n.tr("toast.logsCleared"))
    }

    private func showToast(_ message: String) {
        toastDismissTask?.cancel()

        withAnimation(.easeInOut(duration: 0.2)) {
            toastMessage = message
        }

        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                guard toastMessage == message else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    toastMessage = nil
                }
            }
        }
    }

    private var exportContext: LogExportContext {
        LogExportContext(
            isRunning: coordinator.isRunning,
            localIPAddresses: coordinator.localIPAddresses,
            port: 8887,
            connectedClientCount: coordinator.connectedClientCount,
            locationAuthorizationText: coordinator.locationAuthorizationText,
            backgroundLocationEnabled: backgroundLocationEnabled,
            batteryLevel: coordinator.batteryLevel,
            batteryState: coordinator.batteryState,
            lastLocation: coordinator.lastLocation,
            accuracyText: coordinator.precisionText,
            includePreciseCoordinates: includePreciseCoordinatesInLogExport
        )
    }

    private var backgroundLocationEnabled: Bool {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        return modes.contains("location")
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let build, !build.isEmpty {
            return String(format: L10n.tr("about.versionWithBuild"), version, build)
        }

        return version
    }

    private var diagnosticsWarningCount: Int {
        diagnostics.count
    }

    private var diagnosticsSummaryText: String {
        if diagnosticsWarningCount == 0 {
            return L10n.tr("diagnostics.summaryOk")
        }

        return String(format: L10n.tr("diagnostics.summaryWarnings"), diagnosticsWarningCount)
    }

    private var diagnostics: [DiagnosticItem] {
        var items: [DiagnosticItem] = []

        if coordinator.isRunning {
            if coordinator.lastLocation == nil {
                items.append(
                    DiagnosticItem(
                        title: L10n.tr("diagnostic.noLocation.title"),
                        detail: L10n.tr("diagnostic.noLocation.detail"),
                        action: L10n.tr("diagnostic.noLocation.action")
                    )
                )
            }

            if coordinator.localIPAddresses.isEmpty {
                items.append(
                    DiagnosticItem(
                        title: L10n.tr("diagnostic.noIp.title"),
                        detail: L10n.tr("diagnostic.noIp.detail"),
                        action: L10n.tr("diagnostic.noIp.action")
                    )
                )
            }
        }

        switch coordinator.locationAuthorizationStatus {
        case .notDetermined:
            items.append(
                DiagnosticItem(
                    title: L10n.tr("diagnostic.locationNotDetermined.title"),
                    detail: L10n.tr("diagnostic.locationNotDetermined.detail"),
                    action: L10n.tr("diagnostic.locationNotDetermined.action")
                )
            )
        case .restricted:
            items.append(
                DiagnosticItem(
                    title: L10n.tr("diagnostic.locationRestricted.title"),
                    detail: L10n.tr("diagnostic.locationRestricted.detail"),
                    action: L10n.tr("diagnostic.locationRestricted.action")
                )
            )
        case .denied:
            items.append(
                DiagnosticItem(
                    title: L10n.tr("diagnostic.locationDenied.title"),
                    detail: L10n.tr("diagnostic.locationDenied.detail"),
                    action: L10n.tr("diagnostic.locationDenied.action")
                )
            )
        case .authorizedWhenInUse:
            items.append(
                DiagnosticItem(
                    title: L10n.tr("diagnostic.locationWhenInUse.title"),
                    detail: L10n.tr("diagnostic.locationWhenInUse.detail"),
                    action: L10n.tr("diagnostic.locationWhenInUse.action")
                )
            )
        case .authorizedAlways:
            break
        @unknown default:
            items.append(
                DiagnosticItem(
                    title: L10n.tr("diagnostic.locationUnknown.title"),
                    detail: L10n.tr("diagnostic.locationUnknown.detail"),
                    action: L10n.tr("diagnostic.locationUnknown.action")
                )
            )
        }

        if coordinator.locationAccuracyAuthorization != .fullAccuracy {
            items.append(
                DiagnosticItem(
                    title: L10n.tr("diagnostic.reducedAccuracy.title"),
                    detail: L10n.tr("diagnostic.reducedAccuracy.detail"),
                    action: L10n.tr("diagnostic.reducedAccuracy.action")
                )
            )
        }

        return items
    }
}

private struct SelectableValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

struct DiagnosticItem: Identifiable {
    let title: String
    let detail: String
    let action: String

    var id: String {
        title
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .shadow(radius: 8)
    }
}

private struct DiagnosticsLinkLabel: View {
    let summary: String
    let warningCount: Int

    private var hasWarnings: Bool {
        warningCount > 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: hasWarnings ? "exclamationmark.triangle.fill" : "checkmark.circle")
                .foregroundStyle(hasWarnings ? .orange : .green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("diagnostics.linkTitle"))
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if hasWarnings {
                Text("\(warningCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(.orange, in: Capsule())
            }
        }
    }
}

private struct DiagnosticRow: View {
    let item: DiagnosticItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.headline)

            Text(item.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(item.action)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

private enum LocationPermissionAlert: Identifiable {
    case denied
    case whenInUse
    case restricted

    var id: String {
        switch self {
        case .denied:
            return "denied"
        case .whenInUse:
            return "whenInUse"
        case .restricted:
            return "restricted"
        }
    }
}

private struct DiagnosticsView: View {
    let diagnostics: [DiagnosticItem]
    @Binding var includePreciseCoordinatesInLogExport: Bool
    let copyBriefDiagnostics: () -> Void
    let shareLogFile: () -> Void
    let clearLogs: () -> Void

    var body: some View {
        Form {
            if diagnostics.isEmpty {
                Section {
                    DiagnosticsEmptyState()
                }
            } else {
                Section(L10n.tr("section.diagnostics")) {
                    ForEach(diagnostics) { item in
                        DiagnosticRow(item: item)
                    }
                }
            }

            Section(L10n.tr("diagnostics.logsSection")) {
                Toggle(
                    L10n.tr("diagnostics.includePreciseCoordinates"),
                    isOn: $includePreciseCoordinatesInLogExport
                )

                Button(L10n.tr("diagnostics.copyBrief")) {
                    copyBriefDiagnostics()
                }

                Button(L10n.tr("diagnostics.shareLog")) {
                    shareLogFile()
                }

                Button(L10n.tr("diagnostics.clearLogs"), role: .destructive) {
                    clearLogs()
                }
            }
        }
        .navigationTitle(L10n.tr("diagnostics.title"))
    }
}

private struct DiagnosticsEmptyState: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("diagnostics.summaryOk"))
                    .font(.headline)
                Text(L10n.tr("diagnostics.emptyDetail"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SetupGuideView: View {
    var body: some View {
        Form {
            Section(L10n.tr("setup.permissions.title")) {
                Text(L10n.tr("setup.permissions.request"))

                Text(L10n.tr("setup.permissions.always"))
            }

            Section(L10n.tr("setup.localNetwork.title")) {
                Text(L10n.tr("setup.localNetwork.allow"))

                Text(L10n.tr("setup.localNetwork.why"))
            }

            Section(L10n.tr("setup.network.title")) {
                Text(L10n.tr("setup.network.sameWifi"))

                Text(L10n.tr("setup.network.hotspot"))
            }

            Section(L10n.tr("setup.server.title")) {
                Text(L10n.tr("setup.server.start"))

                Text(L10n.tr("setup.server.clientAddress"))
            }

            Section(L10n.tr("setup.client.title")) {
                Text(L10n.tr("setup.client.connect"))
            }
        }
        .navigationTitle(L10n.tr("setup.title"))
    }
}
