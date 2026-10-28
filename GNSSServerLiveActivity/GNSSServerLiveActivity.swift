import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct GNSSServerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LocationSharingActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "location.fill.viewfinder")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("app.title"))
                        .font(.headline)
                    Text(context.state.status)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Label {
                            Text(verbatim: "\(context.state.clientCount)")
                        } icon: {
                            Image(systemName: "network")
                        }
                        Text(verbatim: "TCP \(context.attributes.port)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 10)
            }
            .padding()
            .activityBackgroundTint(Color(.secondarySystemGroupedBackground))
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "location.fill.viewfinder")
                        .foregroundStyle(Color.accentColor)
                        .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.status)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text(verbatim: "\(context.state.clientCount)")
                    } icon: {
                        Image(systemName: "network")
                    }
                    .font(.caption)
                    .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(L10n.tr("liveActivity.transmittingLocation"))
                        Spacer()
                        Text(verbatim: "TCP \(context.attributes.port)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                Image(systemName: "location.fill")
                    .foregroundStyle(Color.accentColor)
            } compactTrailing: {
                Text(verbatim: "\(context.state.clientCount)")
                    .foregroundStyle(.primary)
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundStyle(Color.accentColor)
            }
            .keylineTint(Color.accentColor)
        }
    }
}
