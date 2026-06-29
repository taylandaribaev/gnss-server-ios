import CoreLocation
import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var coordinator: ServerCoordinator
    @Environment(\.openURL) private var openURL
    @State private var locationPermissionAlert: LocationPermissionAlert?

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
                        Text(error)
                            .foregroundStyle(.red)
                    }

                    Button(coordinator.isRunning ? "Остановить сервер" : "Запустить сервер") {
                        handleServerButton()
                    }
                    .foregroundStyle(coordinator.isRunning ? .red : .blue)
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
