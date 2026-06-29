import Foundation

enum ServerStatus: String {
    case uninitialized = "UNINITIALIZED"
    case awaitingLocation = "AWAITING_LOCATION"
    case transmittingLocation = "TRANSMITTING_LOCATION"
    case locationStopped = "LOCATION_STOPPED"
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
    let locationAge: Float
}

struct ServerResponsePayload: Sendable {
    let status: ServerStatus
    let satellites: Int32
    let location: LocationPayload?
}

