import CoreLocation
import Foundation

final class LocationService: NSObject, CLLocationManagerDelegate {
    /// iOS doesn't expose the number of visible/used GNSS satellites via public API.
    static let unavailableSatelliteCount: Int32 = -1

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
        // A negative horizontalAccuracy means the coordinate isn't valid. Sending it would look like a fix with
        // 0 m accuracy, so skip it. Clients keep the last good fix, same as between updates.
        guard location.horizontalAccuracy >= 0, CLLocationCoordinate2DIsValid(location.coordinate) else {
            AppLogger.shared.debug(.location, "Location update without a valid position skipped")
            return
        }
        if manager.accuracyAuthorization != .fullAccuracy {
            AppLogger.shared.warn(.location, "Location accuracy is reduced")
        }

        // CLLocation only has a wall-clock timestamp. Measure the age on the wall clock, then move it to the
        // monotonic clock, so a clock change between two fixes doesn't change the interval between them.
        let ageNs = MonotonicClock.ns(fromSeconds: -location.timestamp.timeIntervalSinceNow)
        // Core Location uses negative values for "not available".
        let courseValid = location.course >= 0
        let speedValid = location.speed >= 0
        let altitudeValid = location.verticalAccuracy >= 0
        let payload = LocationPayload(
            timestamp: Int64(location.timestamp.timeIntervalSince1970 * 1_000),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            // The schema's `altitude` (4) is ellipsoidal. `CLLocation.altitude` is MSL and goes into
            // `msl_altitude` (13). The two differ by the geoid height, which can be tens of meters.
            altitude: altitudeValid ? location.ellipsoidalAltitude : 0,
            accuracy: Float(max(location.horizontalAccuracy, 0)),
            bearing: Float(courseValid ? location.course : 0),
            speed: Float(speedValid ? location.speed : 0),
            provider: "fused",
            takenAtNs: MonotonicClock.nowNs() - ageNs,
            speedAccuracy: speedValid && location.speedAccuracy >= 0 ? Float(location.speedAccuracy) : nil,
            bearingAccuracy: courseValid && location.courseAccuracy >= 0 ? Float(location.courseAccuracy) : nil,
            verticalAccuracy: altitudeValid ? Float(location.verticalAccuracy) : nil,
            mslAltitude: altitudeValid ? location.altitude : nil
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
