import ActivityKit
import Foundation

struct LocationSharingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let status: String
        let clientCount: Int
        let lastLocationUpdate: Date?
    }

    let port: Int
}

