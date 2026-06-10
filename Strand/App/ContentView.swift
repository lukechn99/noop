import SwiftUI
import StrandDesign

/// Root — the sidebar shell, with the first-run onboarding/pairing wizard overlaid until complete,
/// and a "What's New" changelog sheet shown automatically after an update.
struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("noop.onboarded") private var onboarded = false
    @AppStorage("noop.lastSeenChangelogVersion") private var lastSeenChangelog = ""
    @State private var showWhatsNew = false

    var body: some View {
        ZStack {
            StrandPalette.surfaceBase.ignoresSafeArea()
            RootView()
            if !onboarded {
                OnboardingWizard(onFinished: {
                    onboarded = true
                    lastSeenChangelog = AppChangelog.currentVersion
                })
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: onboarded)
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView(onClose: {
                lastSeenChangelog = AppChangelog.currentVersion
                showWhatsNew = false
            })
        }
        #if os(iOS)
        .sheet(isPresented: $model.showCamera) {
            CameraView()
                .environmentObject(model)
        }
        .sheet(isPresented: $model.showRunActivity) {
            RunActivityView()
                .environmentObject(model)
                .environmentObject(model.live)
        }
        #endif
        .onAppear {
            if onboarded && lastSeenChangelog != AppChangelog.currentVersion {
                showWhatsNew = true
            }
        }
    }
}
