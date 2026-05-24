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
                    title: "Sürücüyüm",
                    subtitle: "Servisi oluştururum, sabah \"Servisi Başlat\" derim ve konumumu paylaşırım.",
                    icon: "steeringwheel",
                    accent: NeonTheme.primary,
                    action: onSelectDriver
                )
                NeonRoleCard(
                    title: "Yolcuyum",
                    subtitle: "Servise katılırım, haritadan takip ederim ve geleceğimi bildiririm.",
                    icon: "person.fill",
                    accent: NeonTheme.secondary,
                    action: onSelectPassenger
                )

                Button(action: viewModel.onLoginTapped) {
                    HStack(spacing: 4) {
                        Text("Zaten hesabım var —")
                            .foregroundStyle(NeonTheme.onSurfaceVariant)
                        Text("Giriş yap")
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
