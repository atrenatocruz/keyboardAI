import SwiftUI

struct RootView: View {
    @AppStorage("onboardingDone") private var onboardingDone = false

    var body: some View {
        if onboardingDone {
            MoodsView(onReplayOnboarding: { onboardingDone = false })
        } else {
            OnboardingView(onFinish: { onboardingDone = true })
        }
    }
}
