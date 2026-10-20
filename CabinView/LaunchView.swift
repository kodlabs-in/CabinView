import SwiftUI

struct LaunchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingSplash = true

    var body: some View {
        ZStack {
            ContentView(browser: .shared).accessibilityHidden(showingSplash)
            if showingSplash { SplashView().transition(.opacity).zIndex(1) }
        }
        .preferredColorScheme(showingSplash ? .dark : nil)
        .task {
            do { try await Task.sleep(for: .milliseconds(700)) }
            catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { showingSplash = false }
        }
    }
}

private struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        ZStack {
            Color("LaunchBackground")
            VStack(spacing: 20) {
                ZStack {
                    RadialGradient(colors: [.cyan.opacity(0.18), .indigo.opacity(0.06), .clear],
                                   center: .center, startRadius: 24, endRadius: 250)
                        .frame(width: 500, height: 500)
                    Circle().stroke(.white.opacity(0.06), lineWidth: 1).frame(width: 240, height: 240)
                    Circle().trim(from: 0.04, to: 0.80)
                        .stroke(AngularGradient(colors: [.cyan.opacity(0.65), .blue.opacity(0.15), .purple.opacity(0.5)],
                                                center: .center), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .frame(width: 202, height: 202)
                        .rotationEffect(.degrees(revealed ? 20 : -25))
                    Image("CabinViewLogo").resizable().frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .shadow(color: .cyan.opacity(0.16), radius: 28, y: 8)
                }
                .frame(width: 240, height: 240)
                .scaleEffect(revealed ? 1 : 0.9)
                VStack(spacing: 8) {
                    Text("CabinView").font(.system(size: 40, weight: .bold, design: .rounded)).tracking(-0.8)
                        .foregroundStyle(.white)
                    Text("The web, in view.").font(.subheadline).foregroundStyle(.white.opacity(0.6))
                }
            }
            .offset(y: -20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).clipped().ignoresSafeArea()
        .accessibilityElement(children: .ignore).accessibilityLabel("CabinView")
        .accessibilityIdentifier("launchSplash")
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6)) { revealed = true }
        }
    }
}
