import SwiftUI

struct PassengerSettingsTab: View {
    @Environment(ShuttleStore.self) private var store
    @Environment(UserSession.self) private var session
    @Environment(AuthService.self) private var authService
    let viewModel: PassengerHomeViewModel
    @Binding var showLanguagePicker: Bool
    @Binding var showMyServices: Bool
    
    var body: some View {
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
                
                SettingsNavigationRow(
                    title: L10n.myShuttles,
                    value: viewModel.profile?.groupName
                ) {
                    showMyServices = true
                }

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
        .overlay {
            if showLanguagePicker {
                LanguagePickerOverlay(isPresented: $showLanguagePicker)
                    .animation(.easeInOut(duration: 0.28), value: showLanguagePicker)
            }
        }
    }
}
