import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()

    private var activity: Activity<LocationSharingActivityAttributes>?
    private var lastUpdateDate = Date.distantPast
    private var shouldBeActive = false

    private init() {}

    func start(clientCount: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        shouldBeActive = true

        Task {
            await endExistingActivities()
            guard shouldBeActive else { return }

            let attributes = LocationSharingActivityAttributes(port: 8887)
            let state = LocationSharingActivityAttributes.ContentState(
                status: "Ожидание геопозиции",
                clientCount: clientCount,
                lastLocationUpdate: nil
            )

            do {
                activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
                lastUpdateDate = Date()
                if !shouldBeActive {
                    await activity?.end(nil, dismissalPolicy: .immediate)
                    activity = nil
                }
            } catch {
                activity = nil
            }
        }
    }

    func update(status: String, clientCount: Int, locationDate: Date?, force: Bool = false) {
        guard let activity else { return }

        // Core Location may deliver multiple fixes per second. Live Activity
        // doesn't need that frequency, so routine location updates are throttled.
        guard force || Date().timeIntervalSince(lastUpdateDate) >= 5 else { return }

        lastUpdateDate = Date()
        let state = LocationSharingActivityAttributes.ContentState(
            status: status,
            clientCount: clientCount,
            lastLocationUpdate: locationDate
        )

        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func stop() {
        shouldBeActive = false
        let finalState = LocationSharingActivityAttributes.ContentState(
            status: "Сервер остановлен",
            clientCount: 0,
            lastLocationUpdate: nil
        )

        Task {
            if let activity {
                await activity.end(
                    ActivityContent(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
            await endExistingActivities()
            self.activity = nil
        }
    }

    private func endExistingActivities() async {
        for existing in Activity<LocationSharingActivityAttributes>.activities {
            await existing.end(nil, dismissalPolicy: .immediate)
        }
    }
}
