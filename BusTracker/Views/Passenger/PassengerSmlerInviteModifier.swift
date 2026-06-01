import SwiftUI

struct PassengerSmlerInviteModifier: ViewModifier {
    @Environment(SmlerInviteCoordinator.self) private var smlerInviteCoordinator
    @Binding var showMyServices: Bool
    @Binding var myServicesInviteCode: String
    @Binding var openAddServiceFromInvite: Bool
    let session: UserSession
    let onAppearCheck: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: smlerInviteCoordinator.pendingAddServiceCode) { _, code in
                guard let code else { return }
                myServicesInviteCode = code
                openAddServiceFromInvite = true
                showMyServices = true
                smlerInviteCoordinator.clearAddServicePending()
            }
            .sheet(isPresented: $showMyServices) {
                MyServicesView(
                    initialServiceCode: myServicesInviteCode,
                    openAddServiceOnAppear: openAddServiceFromInvite
                )
                .environment(session)
                .onDisappear {
                    openAddServiceFromInvite = false
                    myServicesInviteCode = ""
                }
            }
    }
}
