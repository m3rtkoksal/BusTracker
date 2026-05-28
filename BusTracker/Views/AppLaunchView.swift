import Lottie
import SwiftUI

/// Native LaunchScreen sonrası: aynı arka plan + Maps Lottie (Firebase / profil yüklemesi).
struct AppLaunchView: View {
    private let horizontalPadding: CGFloat = 56
    private let maxAnimationSide: CGFloat = 140

    var body: some View {
        ZStack {
            NeonTheme.background
                .ignoresSafeArea()

            GeometryReader { geometry in
                let side = min(
                    maxAnimationSide,
                    (geometry.size.width - horizontalPadding * 2) * 0.55
                )

                LottieView(name: "Maps", loopMode: .loop)
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct LottieView: UIViewRepresentable {
    let name: String
    let loopMode: LottieLoopMode

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true

        let animationView = LottieAnimationView(name: name)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.backgroundBehavior = .pauseAndRestore
        container.addSubview(animationView)

        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        animationView.play()
        context.coordinator.animationView = animationView
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.animationView?.loopMode = loopMode
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var animationView: LottieAnimationView?
    }
}
