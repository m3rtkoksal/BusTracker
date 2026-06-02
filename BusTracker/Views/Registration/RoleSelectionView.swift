import SwiftUI

struct RoleSelectionView: BaseView {
    @State var viewModel: RoleSelectionViewModel
    let onSelectDriver: () -> Void
    let onSelectPassenger: () -> Void

    init(
        onLoginTapped: @escaping () -> Void,
        onSelectDriver: @escaping () -> Void,
        onSelectPassenger: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: RoleSelectionViewModel(onLoginTapped: onLoginTapped))
        self.onSelectDriver = onSelectDriver
        self.onSelectPassenger = onSelectPassenger
    }

    func content() -> some View {
        ScrollView {
            VStack(spacing: 24) {
                NeonRoleCard(
                    title: L10n.iAmDriver,
                    subtitle: L10n.iAmDriverSubtitle,
                    icon: "steeringwheel",
                    accent: NeonTheme.primary,
                    action: onSelectDriver
                )
                NeonRoleCard(
                    title: L10n.iAmPassenger,
                    subtitle: L10n.iAmPassengerSubtitle,
                    icon: "person.fill",
                    accent: NeonTheme.secondary,
                    action: onSelectPassenger
                )

                Button(action: viewModel.onLoginTapped) {
                    HStack(spacing: 4) {
                        Text(L10n.alreadyHaveAccount)
                            .foregroundStyle(NeonTheme.onSurfaceVariant)
                        Text(L10n.signInWithAppleLink)
                            .fontWeight(.semibold)
                            .foregroundStyle(NeonTheme.secondary)
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    RoleSelectionView(onLoginTapped: {}, onSelectDriver: {}, onSelectPassenger: {})
}
