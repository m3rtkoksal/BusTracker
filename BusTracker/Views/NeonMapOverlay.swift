import SwiftUI

struct NeonMapOverlay: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [.clear, NeonTheme.background.opacity(0.15), NeonTheme.background.opacity(0.55)],
                center: .center,
                startRadius: 40,
                endRadius: 420
            )

            NeonScanlineOverlay()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct NeonScanlineOverlay: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 2)
                context.fill(Path(rect), with: .color(NeonTheme.secondary.opacity(0.02)))
                y += 4
            }
        }
    }
}
