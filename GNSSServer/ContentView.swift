import CoreLocation
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var coordinator: ServerCoordinator

    var body: some View {
        NavigationStack {
            Form {
                Section("Сервер") {
                    LabeledContent("Состояние", value: coordinator.statusText)
                    LabeledContent("TCP-порт", value: "8887")
                    LabeledContent("Клиентов", value: "\(coordinator.connectedClientCount)")

                    if coordinator.localIPAddresses.isEmpty {
                        LabeledContent("IP-адрес", value: "Не найден")
                    } else {
                        ForEach(Array(coordinator.localIPAddresses.enumerated()), id: \.element) { index, address in
                            LabeledContent(
                                index == 0 ? "IP-адрес" : "Другой IP",
                                value: address
                            )
                        }
                    }

                    if let error = coordinator.errorText {
                        Text(error)
                            .foregroundStyle(.red)
                    }

                    Button(coordinator.isRunning ? "Остановить сервер" : "Запустить сервер") {
                        coordinator.isRunning ? coordinator.stop() : coordinator.start()
                    }
                    .foregroundStyle(coordinator.isRunning ? .red : .blue)
                }

                Section("Геолокация") {
                    LabeledContent("Разрешение", value: coordinator.locationAuthorizationText)
                    LabeledContent("Точность", value: coordinator.precisionText)

                    if let location = coordinator.lastLocation {
                        LabeledContent(
                            "Координаты",
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

                    Button("Запросить разрешения") {
                        coordinator.requestPermissions()
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
