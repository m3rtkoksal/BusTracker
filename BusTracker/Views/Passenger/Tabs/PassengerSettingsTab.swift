import SwiftUI

struct PassengerSettingsTab: View {
    @Environment(ShuttleStore.self) private var store
    @Environment(UserSession.self) private var session
    @Environment(AuthService.self) private var authService
    let viewModel: PassengerHomeViewModel
    @Binding var showLanguagePicker: Bool
    @Binding var settingsPath: NavigationPath
    @State private var subscriptionViewModel = DriverSubscriptionViewModel()

    private var groupID: String {
        viewModel.profile?.primaryGroupID ?? ""
    }

    var body: some View {
        NavigationStack(path: $settingsPath) {
            ScrollView {
                VStack(spacing: 16) {
                    if let code = viewModel.profile?.groupCode, !code.isEmpty {
                        SettingsServiceCodeRow(code: code) {
                            viewModel.copyServiceCode(code)
                        }
                        SettingsInviteShareRow(serviceCode: code) { message in
                            viewModel.showError(message)
                        }
                    }

                    if let name = viewModel.myMember?.name ?? viewModel.profile?.name {
                        SettingsEditableNameRow(
                            title: L10n.settingsYourName,
                            value: .constant(name)
                        ) { newName in
                            viewModel.updateName(newName)
                        }
                    }

                    SettingsNavigationLinkRow(
                        title: L10n.myShuttles,
                        value: viewModel.profile?.groupName,
                        route: MyServicesRoute()
                    )

                    SettingsNavigationLinkRow(
                        title: L10n.subscription,
                        value: subscriptionViewModel.statusSubtitle,
                        route: ServiceSubscriptionRoute()
                    )

                    LanguageSettingsRow(showPicker: $showLanguagePicker)

                    SettingsSignOutRow {
                        viewModel.requestSignOut {
                            Task { await viewModel.signOut(store: store, session: session) }
                        }
                    }

                    SettingsDeleteAccountLink {
                        viewModel.requestDeleteAccount {
                            Task {
                                await viewModel.deleteAccount(
                                    store: store,
                                    session: session,
                                    authService: authService
                                )
                            }
                        }
                    }
                }
                .padding(24)
            }
            .navigationDestination(for: MyServicesRoute.self) { route in
                MyServicesView(
                    initialServiceCode: route.initialServiceCode,
                    openAddServiceOnAppear: route.openAddServiceOnAppear
                )
            }
            .navigationDestination(for: ServiceSubscriptionRoute.self) { _ in
                DriverSubscriptionView()
            }
        }
        .task(id: groupID) {
            await subscriptionViewModel.load(groupID: groupID)
        }
    }
}
