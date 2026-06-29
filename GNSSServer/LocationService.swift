import CoreLocation
import Foundation

final class LocationService: NSObject, CLLocationManagerDelegate {
    /// iOS doesn't expose the number of visible/used GNSS satellites via public API.
    static let unavailableSatelliteCount: Int32 = 20

    var onLocation: ((LocationPayload) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus, CLAccuracyAuthorization) -> Void)?

    private let manager = CLLocationManager()
    private var shouldRun = false
    private var requestedAlwaysAuthorization = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    var accuracyAuthorization: CLAccuracyAuthorization {
        manager.accuracyAuthorization
    }

    func requestAuthorization() {
        AppLogger.shared.info(.location, "Requesting location authorization from status \(manager.authorizationStatus.rawValue)")
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            requestedAlwaysAuthorization = true
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            if shouldRun {
                manager.startUpdatingLocation()
            }
        case .restricted, .denied:
            onAuthorizationChange?(manager.authorizationStatus, manager.accuracyAuthorization)
        @unknown default:
            break
        }
    }

    func start() {
        shouldRun = true
        AppLogger.shared.info(.location, "Starting location updates")
        requestAuthorization()

        if manager.authorizationStatus == .authorizedAlways
            || manager.authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func stop() {
        shouldRun = false
        manager.stopUpdatingLocation()
        AppLogger.shared.info(.location, "Stopped location updates")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        AppLogger.shared.info(
            .location,
            "Location authorization changed: status=\(manager.authorizationStatus.rawValue), accuracy=\(manager.accuracyAuthorization == .fullAccuracy ? "full" : "reduced")"
        )
        onAuthorizationChange?(manager.authorizationStatus, manager.accuracyAuthorization)

        if manager.authorizationStatus == .authorizedWhenInUse && !requestedAlwaysAuthorization {
            requestedAlwaysAuthorization = true
            manager.requestAlwaysAuthorization()
        }

        if shouldRun && (
            manager.authorizationStatus == .authorizedAlways
                || manager.authorizationStatus == .authorizedWhenInUse
        ) {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        if manager.accuracyAuthorization != .fullAccuracy {
            AppLogger.shared.warn(.location, "Location accuracy is reduced")
        }

        let payload = LocationPayload(
            timestamp: Int64(location.timestamp.timeIntervalSince1970 * 1_000),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.verticalAccuracy >= 0 ? location.altitude : 0,
            accuracy: Float(max(location.horizontalAccuracy, 0)),
            bearing: Float(location.course >= 0 ? location.course : 0),
            speed: Float(location.speed >= 0 ? location.speed : 0),
            provider: "fused",
            locationAge: Float(max(0, -location.timestamp.timeIntervalSinceNow))
        )
        AppLogger.shared.debug(.location, "Location update received with accuracy \(payload.accuracy)m")
        onLocation?(payload)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let coreLocationError = error as? CLError, coreLocationError.code == .locationUnknown {
            return
        }
        AppLogger.shared.error(.location, "Location updates failed: \(error.localizedDescription)")
    }
}
