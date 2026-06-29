import ActivityKit
import SwiftUI
import WidgetKit

struct GNSSServerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LocationSharingActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "location.fill.viewfinder")
                    .font(.title2)
                    .foregroundStyle(.cyan)

                VStack(alignment: .leading, spacing: 4) {
                    Text("GNSS Server")
                        .font(.headline)
                    Text(context.state.status)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Label("\(context.state.clientCount)", systemImage: "network")
                        Text("TCP \(context.attributes.port)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.02, green: 0.08, blue: 0.20))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "location.fill.viewfinder")
                        .foregroundStyle(.cyan)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.status)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label("\(context.state.clientCount)", systemImage: "network")
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Передача геопозиции")
                        Spacer()
                        Text("TCP \(context.attributes.port)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "location.fill")
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                Text("\(context.state.clientCount)")
                    .foregroundStyle(.green)
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundStyle(.cyan)
            }
            .keylineTint(.cyan)
        }
    }
}

