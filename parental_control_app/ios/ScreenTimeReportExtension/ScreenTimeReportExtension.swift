import DeviceActivity
import ExtensionKit
import Foundation
import ManagedSettings
import SwiftUI

/// Must match `ScreenTimeReportConstants.reportContext` in `SwiftIosScreenTimeToolsPlugin.swift`.
private let kReportContext = "parentalcontrol.totalUsage"

/// Must match app group on Runner + this extension (add in Apple Developer → Identifiers → App Groups).
enum ScreenTimeReportAppGroup {
    static let id = "group.com.parentalcontrol.application"
    static let usageSecondsKey = "screen_time_usage_seconds_by_key_v1"
}

@main
struct ScreenTimeReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        ParentalControlTotalUsageScene()
    }
}

private struct ParentalControlTotalUsageScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(kReportContext)

    /// Stored closure avoids `@ViewBuilder` on computed `var`, which rejects function-typed results.
    let content: (String) -> EmptyView = { _ in EmptyView() }

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> String {
        var secondsByKey: [String: TimeInterval] = [:]

        for await datum in data {
            for await segment in datum.activitySegments {
                for await category in segment.categories {
                    for await appActivity in category.applications {
                        let app = appActivity.application
                        let key = Self.appKey(app)
                        secondsByKey[key, default: 0] += appActivity.totalActivityDuration
                    }
                }
            }
        }

        let ints: [String: Int] = secondsByKey.mapValues { Int($0.rounded()) }
        if let shared = UserDefaults(suiteName: ScreenTimeReportAppGroup.id),
           let encoded = try? JSONSerialization.data(withJSONObject: ints, options: []) {
            shared.set(encoded, forKey: ScreenTimeReportAppGroup.usageSecondsKey)
            shared.set(Date().timeIntervalSince1970, forKey: "screen_time_usage_updated_at")
        }
        return ""
    }

    private static func appKey(_ app: Application) -> String {
        if let bid = app.bundleIdentifier, !bid.isEmpty { return bid }
        var hasher = Hasher()
        if let token = app.token {
            hasher.combine(token)
        } else {
            hasher.combine(app.localizedDisplayName ?? "")
        }
        return "opaque_\(hasher.finalize())"
    }
}
