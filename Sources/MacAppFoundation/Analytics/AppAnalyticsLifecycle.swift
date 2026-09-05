import AppKit
import Combine
import SwiftUI

public extension View {
    func managesAnalytics(_ analytics: AppAnalyticsClient) -> some View {
        modifier(AppAnalyticsLifecycleModifier(analytics: analytics))
    }
}

private struct AppAnalyticsLifecycleModifier: ViewModifier {
    let analytics: AppAnalyticsClient

    func body(content: Content) -> some View {
        content
            .task {
                if NSApplication.shared.isActive {
                    try? await analytics.applicationDidBecomeActive()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                Task {
                    try? await analytics.applicationDidBecomeActive()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
                Task {
                    try? await analytics.applicationWillResignActive()
                }
            }
    }
}
