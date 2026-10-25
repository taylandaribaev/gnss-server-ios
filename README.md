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
- UDP discovery on port `8887`: the app answers a client's
  `GNSS_SHARE_DISCOVERY_PROBE_1` with `GNSS_SHARE_DISCOVERY_REPLY_1`, and the
  client takes the reply's source address as the server's. It never
  announces itself. iOS does not deliver the broadcast probes to an app
  without the multicast networking entitlement, so the iPhone answers the
  unicast probes of the client's sweep, which the client runs on networks of
  /24 or narrower. On the iPhone's own hotspot the client finds it as its
  gateway; on wider networks the address has to be typed in
- Client heartbeat: one byte `0x01` or `0x02` every second
- Heartbeat timeout: 3 seconds
- Frame: `[4-byte big-endian payload length][protobuf payload]`
- Protobuf schema: upstream [`proto/location.proto`](https://github.com/DezzK/gnss-share/blob/main/proto/location.proto)
- Only fixes with a valid position are sent. Core Location marks an invalid
  one with a negative `horizontalAccuracy`, which would otherwise go out as an
  accuracy of 0 m
- `satellites`: `-1`, because public iOS APIs do not expose the visible/used
  GNSS satellite count; `satellites_used_in_fix` (5) and the per-satellite
  details a `0x02` heartbeat asks for are left out for the same reason
- `altitude` (4): height above the WGS 84 ellipsoid
  (`CLLocation.ellipsoidalAltitude`), as the schema defines it. The height above
  mean sea level goes in `msl_altitude` (13). With no valid altitude, `altitude`
  is `0` and fields 8, 13 and 14 are left out, so the client knows the `0` is
  not a real value
- `location_age` (10): seconds from the fix to the moment the update is built.
  Core Location stamps a fix with the wall clock only, so the stretch up to the
  delegate callback is read there; from the callback on, the monotonic clock
  (`CLOCK_MONOTONIC_RAW`, which counts sleep like Android's
  `elapsedRealtimeNanos`) is used
- Newer `optional` fields of the schema, sent only when Core Location has a
  valid value, so a client can tell "unknown" from `0`. They are not in the
  version of the schema linked above, so here are their numbers and types;
  clients that do not know them skip them:
  - `speed_accuracy` (11, float, m/s) from `CLLocation.speedAccuracy`
  - `bearing_accuracy` (12, float, degrees) from `CLLocation.courseAccuracy`
  - `vertical_accuracy` (8, float, m) from `CLLocation.verticalAccuracy`
  - `msl_altitude` (13, double) from `CLLocation.altitude` and
    `msl_altitude_accuracy` (14, float) from `verticalAccuracy`
  - `server_monotonic_ns` (15, int64): the fix's moment on the monotonic clock,
    estimated as the callback's moment less the fix's age. Only differences
    between two fixes mean anything: the interval between the fixes, free of
    the delays after the callback (the network, the client)
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
