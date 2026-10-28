import Foundation

enum ServerStatus: String {
    case uninitialized = "UNINITIALIZED"
    case awaitingLocation = "AWAITING_LOCATION"
    case transmittingLocation = "TRANSMITTING_LOCATION"
    case locationStopped = "LOCATION_STOPPED"
}

/// Monotonic time in nanoseconds. `CLOCK_MONOTONIC_RAW` keeps counting during sleep, like Android's
/// `elapsedRealtimeNanos`, and isn't affected by wall clock changes.
enum MonotonicClock {
    static let nsPerSecond: Int64 = 1_000_000_000
    /// Upper bound for a span in seconds: half of what `Int64` nanoseconds can hold, so subtracting it from a
    /// timestamp can't overflow.
    private static let maxSeconds = Double(Int64.max / 2 / nsPerSecond)

    static func nowNs() -> Int64 {
        Int64(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW))
    }

    /// Converts seconds to nanoseconds, clamped to `[0, maxSeconds]` (converting a larger Double would crash).
    static func ns(fromSeconds seconds: Double) -> Int64 {
        Int64(min(max(seconds, 0), maxSeconds) * Double(nsPerSecond))
    }
}

struct LocationPayload: Sendable {
    let timestamp: Int64
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let accuracy: Float
    let bearing: Float
    let speed: Float
    let provider: String
    /// When the fix was taken, on `MonotonicClock`. Estimated, because CLLocation only has a wall-clock
    /// timestamp (see `LocationService`). `location_age` is measured from it, and it's sent as
    /// `server_monotonic_ns`.
    let takenAtNs: Int64
    /// Optional fields: nil when Core Location has no valid value. They're only sent when set, so the client
    /// can tell "unknown" from 0.
    let speedAccuracy: Float?
    let bearingAccuracy: Float?
}

struct ServerResponsePayload: Sendable {
    let status: ServerStatus
    let satellites: Int32
    let location: LocationPayload?
}
