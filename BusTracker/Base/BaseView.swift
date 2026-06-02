import SwiftUI

@MainActor
protocol BaseView: View {
    associatedtype ViewModelType: BaseViewModel
    associatedtype TrailingToolbarContent: View
    associatedtype ScreenContent: View

    var viewModel: ViewModelType { get }
    var onBack: (() -> Void)? { get }

    @ViewBuilder func trailingToolbar() -> TrailingToolbarContent
    @ViewBuilder func content() -> ScreenContent
}

extension BaseView {
    var onBack: (() -> Void)? { nil }

    @ViewBuilder
    func trailingToolbar() -> EmptyView {
        EmptyView()
    }

    var body: some View {
        BaseViewShell(
            viewModel: viewModel,
            onBack: onBack,
            trailingToolbar: trailingToolbar,
            content: content
        )
    }
}

struct BaseViewShell<VM: BaseViewModel, Content: View, TrailingToolbar: View>: View {
    @Bindable var viewModel: VM
    var onBack: (() -> Void)?
    @ViewBuilder var trailingToolbar: () -> TrailingToolbar
    @ViewBuilder var content: () -> Content

    init(
        viewModel: VM,
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailingToolbar: @escaping () -> TrailingToolbar = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.viewModel = viewModel
        self.onBack = onBack
        self.trailingToolbar = trailingToolbar
        self.content = content
    }

    var body: some View {
        Group {
            if viewModel.embedsInNavigationStack {
                NavigationStack {
                    screenContent
                }
            } else {
                screenContent
            }
        }
    }

    private var screenContent: some View {
        ZStack {
            if viewModel.navigationBarStyle.usesNeonBackground {
                NeonBackgroundView()
            }

            VStack(spacing: 0) {
                if viewModel.navigationBarStyle.usesCustomNavHeader {
                    BaseNeonNavHeader(
                        title: viewModel.title,
                        subtitle: viewModel.subtitle,
                        subtitleStyle: viewModel.navSubtitleStyle
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }

                ZStack(alignment: .top) {
                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if viewModel.isLoading {
                        loadingOverlay
                    }

                    if let toast = viewModel.toast {
                        toastBanner(toast)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(1)
                    }
                }
            }
        }
        .preferredColorScheme(viewModel.navigationBarStyle.usesNeonBackground ? .dark : nil)
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(viewModel.usesLargeTitle ? .large : .inline)
        .toolbar(viewModel.hidesNavigationBar || viewModel.navigationBarStyle.usesCustomNavHeader ? .hidden : .visible, for: .navigationBar)
        .toolbarBackground(viewModel.navigationBarStyle.backgroundColor, for: .navigationBar)
        .toolbarBackground(viewModel.navigationBarStyle.usesTransparentBar ? .hidden : .visible, for: .navigationBar)
        .modifier(NavigationBarColorSchemeModifier(style: viewModel.navigationBarStyle))
        .toolbar {
            if viewModel.showsBackButton, let onBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onBack) {
                        Label(L10n.back, systemImage: "chevron.left")
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                trailingToolbar()
            }
        }
        .alert(item: $viewModel.alert) { popup in
            Alert(
                title: Text(popup.title),
                message: Text(popup.message),
                dismissButton: .default(Text(L10n.ok)) {
                    viewModel.clearAlert()
                }
            )
        }
        .confirmationDialog(
            viewModel.confirmDialog?.title ?? "",
            isPresented: Binding(
                get: { viewModel.confirmDialog != nil },
                set: { if !$0 { viewModel.clearConfirmDialog() } }
            ),
            titleVisibility: .visible
        ) {
            if let dialog = viewModel.confirmDialog {
                Button(dialog.confirmTitle, role: dialog.isDestructive ? .destructive : nil) {
                    viewModel.confirmDialogAction()
                }
                Button(dialog.cancelTitle, role: .cancel) {
                    viewModel.clearConfirmDialog()
                }
            }
        } message: {
            if let dialog = viewModel.confirmDialog {
                Text(dialog.message)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.toast?.id)
        .task(id: viewModel.toast?.id) {
            guard viewModel.toast != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            viewModel.clearToast()
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text(viewModel.loadingMessage)
                    .font(.subheadline)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .zIndex(2)
    }

    private func toastBanner(_ popup: PopupPresentation) -> some View {
        HStack(spacing: 10) {
            Image(systemName: popup.style.iconName)
                .foregroundStyle(popup.style.tint)
            VStack(alignment: .leading, spacing: 2) {
                if !popup.title.isEmpty {
                    Text(popup.title).font(.subheadline.weight(.semibold))
                }
                Text(popup.message).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { viewModel.clearToast() } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

private struct NavigationBarColorSchemeModifier: ViewModifier {
    let style: NavigationBarStyle

    func body(content: Content) -> some View {
        switch style {
        case .driver, .passenger, .neonAuth, .neonDriver, .neonPassenger:
            content.toolbarColorScheme(.dark, for: .navigationBar)
        case .primary, .auth:
            content
        }
    }
}

private struct BaseNeonNavHeader: View {
    let title: String
    let subtitle: String
    let subtitleStyle: NavSubtitleStyle

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(NeonTheme.onSurface)
                .multilineTextAlignment(.center)

            if subtitleStyle != .hidden, !subtitle.isEmpty {
                switch subtitleStyle {
                case .neonCaps:
                    Text(subtitle.uppercased())
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(NeonTheme.secondary)
                        .multilineTextAlignment(.center)
                        .shadow(color: NeonTheme.secondary.opacity(0.6), radius: 8)
                case .standard, .hidden:
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(NeonTheme.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
