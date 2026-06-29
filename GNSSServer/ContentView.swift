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

    var body: some View {
        NavigationStack {
            Form {
                Section("Сервер") {
                    LabeledContent("Состояние", value: coordinator.statusText)
                    SelectableValueRow(label: "TCP-порт", value: "8887")
                    LabeledContent("Клиентов", value: "\(coordinator.connectedClientCount)")

                    if coordinator.localIPAddresses.isEmpty {
                        LabeledContent("IP-адрес", value: "Не найден")
                    } else {
                        ForEach(Array(coordinator.localIPAddresses.enumerated()), id: \.element) { index, address in
                            SelectableValueRow(
                                label: index == 0 ? "IP-адрес" : "Другой IP",
                                value: address
                            )
                        }
                    }

                    if let error = coordinator.errorText {
                        Label(error, systemImage: "exclamationmark.triangle")
                    }

                    Button(coordinator.isRunning ? "Остановить сервер" : "Запустить сервер", role: coordinator.isRunning ? .destructive : nil) {
                        handleServerButton()
                    }
                }

                Section("Геолокация") {
                    LabeledContent("Разрешение", value: coordinator.locationAuthorizationText)
                    LabeledContent("Точность", value: coordinator.precisionText)

                    if let location = coordinator.lastLocation {
                        SelectableValueRow(
                            label: "Координаты",
                            value: String(format: "%.6f, %.6f", location.latitude, location.longitude)
                        )
                        LabeledContent(
                            "Погрешность",
                            value: String(format: "%.1f м", location.accuracy)
                        )
                    } else {
                        Text("Координаты ещё не получены")
                            .foregroundStyle(.secondary)
                    }

                    if coordinator.shouldShowLocationPermissionButton {
                        Button("Запросить разрешения") {
                            handlePermissionButton()
                        }
                    }
                }

                Section("Диагностика") {
                    ForEach(diagnostics) { item in
                        DiagnosticRow(item: item)
                    }

                    Toggle(
                        "Включать точные координаты в экспорт логов",
                        isOn: $includePreciseCoordinatesInLogExport
                    )

                    Button("Скопировать краткую диагностику") {
                        copyBriefDiagnostics()
                    }

                    Button("Поделиться лог-файлом") {
                        shareLogFile()
                    }

                    Button("Очистить логи", role: .destructive) {
                        AppLogger.shared.clear()
                        showToast("Логи очищены")
                    }
                }

                Section {
                    NavigationLink {
                        SetupGuideView()
                    } label: {
                        Label("Инструкция по настройке", systemImage: "questionmark.circle")
                    }
                }

                Section("Фоновая работа") {
                    Text(
                        "Пока сервер запущен, приложение использует фоновую геолокацию. "
                        + "Это позволяет продолжать передачу данных после блокировки устройства. "
                        + "Активный сервер может заметно расходовать батарею; для длительных поездок "
                        + "рекомендуется держать iPhone подключённым к питанию."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("GNSS Server")
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
                        title: Text("Геолокация отключена"),
                        message: Text(
                            "GNSS Server не сможет работать без доступа к геолокации. "
                            + "Откройте настройки iOS и разрешите доступ к геопозиции для этого приложения."
                        ),
                        primaryButton: .default(Text("Настройки")) {
                            openAppSettings()
                        },
                        secondaryButton: .cancel(Text("Отмена"))
                    )
                case .whenInUse:
                    return Alert(
                        title: Text("Нужен доступ «Всегда»"),
                        message: Text(
                            "С доступом «При использовании» сервер может остановиться после блокировки экрана. "
                            + "Для стабильной передачи координат в фоне выберите доступ к геопозиции «Всегда»."
                        ),
                        primaryButton: .default(Text("Настройки")) {
                            openAppSettings()
                        },
                        secondaryButton: .default(Text("Запросить снова")) {
                            coordinator.requestPermissions()
                        }
                    )
                case .restricted:
                    return Alert(
                        title: Text("Геолокация ограничена"),
                        message: Text(
                            "iOS ограничивает доступ к геолокации для этого приложения. "
                            + "Проверьте настройки устройства, иначе GNSS Server не сможет передавать координаты."
                        ),
                        primaryButton: .default(Text("Настройки")) {
                            openAppSettings()
                        },
                        secondaryButton: .cancel(Text("Отмена"))
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
        showToast("Краткая диагностика скопирована")
        AppLogger.shared.info(.export, "Brief diagnostics copied")
    }

    private func shareLogFile() {
        do {
            let url = try LogExportService.exportLogFile(context: exportContext)
            shareItem = ShareItem(url: url)
            showToast("Лог-файл подготовлен")
        } catch {
            showToast("Не удалось подготовить лог-файл")
            AppLogger.shared.error(.export, "Log export failed: \(error.localizedDescription)")
        }
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

    private var diagnostics: [DiagnosticItem] {
        var items: [DiagnosticItem] = []

        if coordinator.isRunning {
            if coordinator.connectedClientCount == 0 {
                items.append(
                    DiagnosticItem(
                        title: "Нет клиентов",
                        detail: "К серверу пока не подключилось ни одно устройство.",
                        action: "Проверьте, что клиент подключён к той же Wi-Fi сети или точке доступа iPhone, и укажите IP-адрес из блока «Сервер» и порт 8887."
                    )
                )

                items.append(
                    DiagnosticItem(
                        title: "Локальная сеть может быть не разрешена",
                        detail: "iOS не даёт приложению напрямую показать статус этого разрешения.",
                        action: "Если клиент не видит сервер, откройте настройки iOS для GNSS Server и включите доступ к локальной сети."
                    )
                )
            }

            if coordinator.lastLocation == nil {
                items.append(
                    DiagnosticItem(
                        title: "Нет координат",
                        detail: "Сервер запущен, но iPhone ещё не получил актуальную геопозицию.",
                        action: "Выйдите на открытое место, включите точную геопозицию и подождите несколько секунд."
                    )
                )
            }

            if coordinator.localIPAddresses.isEmpty {
                items.append(
                    DiagnosticItem(
                        title: "Нет IP-адреса",
                        detail: "Приложение не нашло локальный IPv4-адрес для подключения клиента.",
                        action: "Подключите iPhone к Wi-Fi или включите точку доступа, затем проверьте адрес ещё раз."
                    )
                )
            }

            if coordinator.batteryState == .unplugged {
                items.append(
                    DiagnosticItem(
                        title: "iPhone не подключён к питанию",
                        detail: "Активный GNSS server и фоновая геолокация могут заметно расходовать батарею.",
                        action: "Для длительных поездок подключите iPhone к зарядке."
                    )
                )
            }

            items.append(
                DiagnosticItem(
                    title: "Сервер работает в фоне",
                    detail: "iOS может ограничивать работу приложений в фоне, особенно после принудительного закрытия.",
                    action: "Не закрывайте приложение из переключателя приложений, оставьте доступ к геопозиции «Всегда» и следите за Live Activity."
                )
            )
        } else {
            items.append(
                DiagnosticItem(
                    title: "Сервер остановлен",
                    detail: "Клиенты не смогут подключиться, пока сервер не запущен.",
                    action: "Нажмите «Запустить сервер» после выдачи разрешений."
                )
            )
        }

        switch coordinator.locationAuthorizationStatus {
        case .notDetermined:
            items.append(
                DiagnosticItem(
                    title: "Геолокация ещё не разрешена",
                    detail: "Без геолокации сервер не сможет передавать координаты.",
                    action: "Нажмите «Запросить разрешения» и разрешите доступ к геопозиции."
                )
            )
        case .restricted:
            items.append(
                DiagnosticItem(
                    title: "Геолокация ограничена",
                    detail: "Система ограничивает доступ приложения к геопозиции.",
                    action: "Проверьте настройки устройства и ограничения Screen Time."
                )
            )
        case .denied:
            items.append(
                DiagnosticItem(
                    title: "Геолокация запрещена",
                    detail: "GNSS Server не сможет работать без доступа к геопозиции.",
                    action: "Откройте настройки iOS для приложения и разрешите геолокацию."
                )
            )
        case .authorizedWhenInUse:
            items.append(
                DiagnosticItem(
                    title: "Геолокация не «Всегда»",
                    detail: "С доступом «При использовании» сервер может остановиться после блокировки экрана.",
                    action: "В настройках iOS выберите доступ к геопозиции «Всегда»."
                )
            )
        case .authorizedAlways:
            break
        @unknown default:
            items.append(
                DiagnosticItem(
                    title: "Неизвестный статус геолокации",
                    detail: "iOS вернула статус разрешения, который приложение не распознало.",
                    action: "Проверьте настройки геолокации и перезапустите приложение."
                )
            )
        }

        if coordinator.locationAccuracyAuthorization != .fullAccuracy {
            items.append(
                DiagnosticItem(
                    title: "Нет точной геопозиции",
                    detail: "Координаты могут быть недостаточно точными для GNSS-клиента.",
                    action: "В настройках геолокации для приложения включите «Точная геопозиция»."
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

private struct SetupGuideView: View {
    var body: some View {
        Form {
            Section("1. Разрешения") {
                Text(
                    "Нажмите «Запросить разрешения» в основном экране и разрешите геолокацию."
                )

                Text(
                    "Для стабильной работы при заблокированном экране выберите доступ к геопозиции «Всегда» "
                    + "и включите точную геопозицию."
                )
            }

            Section("2. Локальная сеть") {
                Text(
                    "Разрешите доступ к локальной сети, когда iOS покажет запрос."
                )

                Text(
                    "Он нужен, чтобы клиентское устройство могло подключиться к GNSS-серверу на этом iPhone."
                )
            }

            Section("3. Wi-Fi или точка доступа") {
                Text(
                    "Подключите iPhone и клиентское устройство к одной сети Wi-Fi."
                )

                Text(
                    "Если общей сети нет, включите точку доступа на iPhone и подключите к ней клиентское устройство."
                )
            }

            Section("4. Запуск сервера") {
                Text(
                    "Нажмите «Запустить сервер». В разделе «Сервер» появится IP-адрес."
                )

                Text(
                    "В GPS/GNSS-клиенте укажите этот IP-адрес и TCP-порт 8887."
                )
            }

            Section("5. Подключение клиента") {
                Text(
                    "Запустите клиентскую службу и убедитесь, что количество клиентов в этом приложении стало больше нуля."
                )
            }
        }
        .navigationTitle("Инструкция")
    }
}
