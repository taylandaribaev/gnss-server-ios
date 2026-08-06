# GPS Server for iOS

GPS Server for iOS is a free and open-source iOS implementation of the
server side for sharing GNSS/location data with clients on the local network.

The project is distributed under the GNU General Public License v3.0
(GPL-3.0). See [LICENSE](LICENSE) for the full license text.

## Protocol Compatibility

This project is compatible with the protocol used by
[`DezzK/gnss-share`](https://github.com/DezzK/gnss-share). It is not an
official port or official app.

- TCP port: `8887`
- Client heartbeat: one byte `0x01` or `0x02` every second
- Heartbeat timeout: 3 seconds
- Frame: `[4-byte big-endian payload length][protobuf payload]`
- Protobuf schema: upstream [`proto/location.proto`](https://github.com/DezzK/gnss-share/blob/main/proto/location.proto)
- `satellites`: `-1`, because public iOS APIs do not expose the visible/used
  GNSS satellite count
- Live Activity on the Lock Screen and Dynamic Island shows active
  transmission, client count, and ends immediately after the server stops

The app intentionally keeps the same wire protocol used by the Android
server. The built-in `ProtocolCodec` encodes protobuf messages directly, so
SwiftProtobuf is not required to build the project.

## Running from Xcode

1. Open `GNSSServer.xcodeproj`.
2. Select the **GNSSServer** scheme, not `GNSSServerLiveActivity`.
3. Select a real iOS device and your signing team.
4. Run the main app. The Live Activity cannot be launched as a separate
   widget; it is created by the app after tapping **Запустить сервер**.
5. Allow location, precise location, and local network access.
6. Tap **Запустить сервер**.

The simulator is useful for checking UI and TCP behavior, but background
operation and behavior while the screen is locked should be tested on a real
device.

## Background Location

The app enables the iOS `location` background mode. While the server is
running, Core Location stays active so iOS can continue executing the app
while the device is locked and can keep serving the TCP listener.

This is required because the app is a live GPS server: connected clients need
fresh coordinates even when the iPhone screen is off. Automatic startup and
Bluetooth logic are not implemented.

## Battery Usage

GPS Server for iOS uses foreground and background location while the server
is active. Continuous GNSS/location updates and local network serving can
noticeably increase battery usage. For long trips, keeping the iPhone
connected to power is recommended.

## Diagnostic Logs

The app includes an in-app diagnostics section with connection hints and log
export actions. You can copy a short diagnostic summary, share a generated
`.log` file through the standard iOS Share Sheet, or clear the current in-memory
logs.

Diagnostic logs include app/device metadata, server state, IP/port, client
count, location permission state, battery state, recent server/client/location
events, and counters such as packets sent, heartbeats received, and send
errors.

Precise coordinates are not included by default. The app has an explicit toggle
to include precise coordinates in exported logs. If you enable that option,
review the generated log before sending it to anyone.

## Credits

Original project: [`DezzK/gnss-share`](https://github.com/DezzK/gnss-share)

Original author: DezzK

Thank you to DezzK for creating and publishing the original project. Upstream
links are included for attribution and protocol compatibility.

## Support the Original Author

If the original author provides a donation/support link, it will be added
here.

## Disclaimer

GPS Server for iOS is an unofficial project. It is not affiliated with or
endorsed by DezzK or the DezzK/gnss-share project. All references to the
upstream project are included for attribution and protocol compatibility.
