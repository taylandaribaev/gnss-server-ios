# GNSS Server for iOS

Черновая iOS-реализация server-части GNSS Sharing System.

## Upstream reference

Проект создавался как iOS-сервер, совместимый с Android-проектом
[`DezzK/gnss-share`](https://github.com/DezzK/gnss-share). Исходный Android-проект
распространяется под GPL-3.0; перед коммерческим распространением iOS-приложения
нужно отдельно проверить лицензионные риски совместимости протокола.

## Совместимость

- TCP port: `8887`
- Heartbeat клиента: один байт `0x01` каждую секунду
- Heartbeat timeout: 3 секунды
- Frame: `[4-byte big-endian payload length][protobuf payload]`
- Protobuf schema: upstream [`proto/location.proto`](https://github.com/DezzK/gnss-share/blob/main/proto/location.proto)
- `satellites`: константа `20`, потому что публичный iOS API не предоставляет число GNSS-спутников
- Live Activity на экране блокировки и Dynamic Island показывает активную передачу,
  число клиентов и завершается сразу после остановки сервера

Приложение намеренно использует тот же wire-протокол, что Android server. Встроенный
`ProtocolCodec` кодирует сообщения protobuf напрямую, поэтому внешняя зависимость
SwiftProtobuf для сборки не требуется.

## Запуск

1. Открыть `GNSSServer.xcodeproj`.
2. В списке схем выбрать **GNSSServer**, а не `GNSSServerLiveActivity`.
3. Выбрать реальное iOS-устройство и signing team.
4. Запустить основное приложение. Live Activity нельзя запускать как отдельный
   виджет: она создаётся приложением после нажатия **Запустить сервер**.
5. Разрешить геолокацию, точную геопозицию и локальную сеть.
6. Нажать **Запустить сервер**.

Симулятор подходит для проверки UI и TCP, но фоновую работу и поведение при
блокировке экрана нужно проверять на реальном устройстве.

## Фоновая работа

В target включён background mode `location`. Пока сервер запущен, Core Location
остаётся активным, чтобы iOS продолжала выполнение приложения при заблокированном
экране и могла обслуживать TCP listener. Автоматический запуск и Bluetooth-логика
отсутствуют.
