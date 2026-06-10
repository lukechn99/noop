#if os(iOS)
import SwiftUI
import StrandDesign

struct RunActivityView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveState
    @Environment(\.dismiss) private var dismiss

    @State private var elapsed: TimeInterval = 0
    @State private var hrSamples: [Int] = []

    private var avgBpm: Int? {
        guard !hrSamples.isEmpty else { return nil }
        return hrSamples.reduce(0, +) / hrSamples.count
    }
    private var maxBpm: Int? { hrSamples.max() }

    var body: some View {
        NavigationStack {
            ZStack {
                StrandPalette.surfaceBase.ignoresSafeArea()
                VStack(spacing: 0) {
                    Spacer()

                    // Elapsed time
                    Text(formatDuration(elapsed))
                        .font(.system(size: 72, weight: .semibold).monospacedDigit())
                        .foregroundStyle(StrandPalette.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.3), value: elapsed)

                    Text("elapsed")
                        .font(StrandFont.caption)
                        .foregroundStyle(StrandPalette.textTertiary)
                        .padding(.top, 4)

                    Spacer().frame(height: 40)

                    // Live heart rate
                    VStack(spacing: 6) {
                        Text("HEART RATE")
                            .font(StrandFont.overline)
                            .tracking(StrandFont.overlineTracking)
                            .foregroundStyle(StrandPalette.textSecondary)
                        Text(model.bpm.map(String.init) ?? "—")
                            .font(.system(size: 80, weight: .semibold).monospacedDigit())
                            .foregroundStyle(model.bpm == nil
                                             ? StrandPalette.textTertiary
                                             : StrandPalette.accent)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: model.bpm)
                        Text("bpm")
                            .font(StrandFont.caption)
                            .foregroundStyle(StrandPalette.textSecondary)
                    }

                    Spacer().frame(height: 32)

                    // Avg / max stats (appear once we have data)
                    if avgBpm != nil || maxBpm != nil {
                        HStack(spacing: 40) {
                            if let avg = avgBpm { statCell("Avg", "\(avg)") }
                            if let max = maxBpm { statCell("Max", "\(max)") }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 40)
                        .background(StrandPalette.surfaceRaised,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 30)
                    }

                    Spacer()

                    Button(role: .destructive) { endRun() } label: {
                        Text("End Run")
                            .font(StrandFont.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StrandPalette.metricRose)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Running")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { endRun() }
                        .foregroundStyle(StrandPalette.textSecondary)
                }
            }
        }
        // Tick elapsed every second
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard let start = model.activeRun?.startedAt else { return }
            elapsed = Date().timeIntervalSince(start)
        }
        // Record HR samples for avg/max
        .onChange(of: model.bpm) { bpm in
            if let bpm { hrSamples.append(bpm) }
        }
    }

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(StrandFont.overline)
                .tracking(StrandFont.overlineTracking)
                .foregroundStyle(StrandPalette.textSecondary)
            Text(value)
                .font(.system(size: 28, weight: .semibold).monospacedDigit())
                .foregroundStyle(StrandPalette.textPrimary)
            Text("bpm")
                .font(StrandFont.caption)
                .foregroundStyle(StrandPalette.textTertiary)
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private func endRun() {
        model.activeRun = nil
        model.showRunActivity = false
        dismiss()
    }
}
#endif
