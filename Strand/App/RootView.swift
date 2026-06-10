import SwiftUI
import StrandDesign

enum NavItem: String, CaseIterable, Identifiable, Hashable {
    case today = "Today"
    case intelligence = "Intelligence"
    case coach = "Coach"
    case live = "Live"
    case breathe = "Breathe"
    case intervals = "Intervals"
    case explore = "Explore"
    case compare = "Compare"
    case insights = "Insights"
    case sleep = "Sleep"
    case trends = "Trends"
    case workouts = "Workouts"
    case health = "Health"
    case stress = "Stress"
    case appleHealth = "Apple Health"
    case dataSources = "Data Sources"
    case notifications = "Notifications"
    case automation = "Automations"
    case settings = "Settings"
    case support = "Support"

    var id: String { rawValue }

    var titleKey: LocalizedStringKey { LocalizedStringKey(rawValue) }

    var icon: String {
        switch self {
        case .today:         return "circle.hexagongrid.fill"
        case .intelligence:  return "brain.head.profile"
        case .coach:         return "sparkles"
        case .live:          return "waveform.path.ecg"
        case .breathe:       return "lungs.fill"
        case .intervals:     return "timer"
        case .explore:       return "square.grid.2x2.fill"
        case .compare:       return "chart.line.uptrend.xyaxis"
        case .insights:      return "lightbulb.fill"
        case .sleep:         return "moon.stars.fill"
        case .trends:        return "chart.xyaxis.line"
        case .workouts:      return "figure.run"
        case .health:        return "heart.text.square.fill"
        case .stress:        return "gauge.with.dots.needle.50percent"
        case .appleHealth:   return "heart.fill"
        case .dataSources:   return "square.and.arrow.down.fill"
        case .notifications: return "bell.badge.fill"
        case .automation:    return "wand.and.stars"
        case .settings:      return "gearshape.fill"
        case .support:       return "heart.fill"
        }
    }

    static let sections: [(title: String, items: [NavItem])] = [
        ("Dashboard",  [.today, .intelligence, .coach]),
        ("Live",       [.live, .breathe, .intervals]),
        ("Metrics",    [.explore, .compare, .insights, .sleep, .trends, .workouts, .health, .stress, .appleHealth]),
        ("Manage",     [.dataSources, .notifications, .automation, .settings, .support]),
    ]
}

struct RootView: View {
    @EnvironmentObject var repo: Repository

    var body: some View {
        NavigationStack {
            List {
                ForEach(NavItem.sections, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            NavigationLink(value: item) {
                                Label(item.titleKey, systemImage: item.icon)
                                    .font(.system(size: 15, weight: .medium))
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("NOOP")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(StrandPalette.surfaceBase, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                ConnectionStatusBar()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(StrandPalette.surfaceBase)
            }
            .navigationDestination(for: NavItem.self) { item in
                detailView(for: item)
                    .toolbarBackground(StrandPalette.surfaceBase, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
        }
        .task { await repo.refresh() }
    }

    @ViewBuilder private func detailView(for item: NavItem) -> some View {
        switch item {
        case .today:         TodayView()
        case .intelligence:  IntelligenceView()
        case .coach:         CoachView()
        case .live:          LiveView()
        case .breathe:       BreathingView()
        case .intervals:     IntervalTimerView()
        case .explore:       MetricExplorerView()
        case .compare:       CompareView()
        case .insights:      InsightsView()
        case .sleep:         SleepView()
        case .trends:        TrendsView()
        case .workouts:      WorkoutsView()
        case .health:        HealthView()
        case .stress:        StressView()
        case .appleHealth:   AppleHealthView()
        case .dataSources:   DataSourcesView()
        case .notifications: NotificationSettingsView()
        case .automation:    AutomationsView()
        case .settings:      SettingsView()
        case .support:       SupportView()
        }
    }
}

/// Isolated connection status bar — owns the LiveState observation so the nav list
/// doesn't re-render on the ~1 Hz HR / frame stream.
private struct ConnectionStatusBar: View {
    @EnvironmentObject var live: LiveState
    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
                .shadow(color: statusColor.opacity(0.6), radius: live.connected ? 4 : 0)
            VStack(alignment: .leading, spacing: 1) {
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(StrandPalette.textPrimary)
                Text(live.batteryPct.map { "Battery \(Int($0))%" } ?? "Strap not connected")
                    .font(.system(size: 11))
                    .foregroundStyle(StrandPalette.textTertiary)
            }
            Spacer()
        }
        .padding(10)
        .background(StrandPalette.surfaceRaised, in: RoundedRectangle(cornerRadius: 10))
    }

    private var statusColor: Color {
        live.bonded ? StrandPalette.statusPositive
            : live.connected ? StrandPalette.statusWarning
            : StrandPalette.statusCritical
    }
    private var statusText: String {
        live.bonded ? "WHOOP · Bonded" : live.connected ? "Connecting…" : "Disconnected"
    }
}
