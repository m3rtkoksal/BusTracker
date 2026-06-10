import SwiftUI
import WebKit

struct SubscriptionPaymentWebView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SubscriptionWebView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .background(NeonTheme.background)
                .navigationTitle(L10n.subscriptionPayment)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(NeonTheme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.close) {
                            dismiss()
                        }
                        .foregroundStyle(NeonTheme.secondary)
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

private struct SubscriptionWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
