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

                Section("Фоновая работа") {
                    Text(
                        "Пока сервер запущен, приложение использует фоновую геолокацию. "
                        + "Это позволяет продолжать передачу данных после блокировки устройства."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("GNSS Server")
        }
    }
}
