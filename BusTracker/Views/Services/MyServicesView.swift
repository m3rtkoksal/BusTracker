import SwiftUI
import FirebaseFirestore

struct MyServicesView: View {
    @Environment(UserSession.self) private var session
    @Environment(ShuttleStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var initialServiceCode: String = ""
    var openAddServiceOnAppear: Bool = false

    private var profile: UserProfile? {
        session.profile
    }

    @State private var tripStartTime: Date? = nil
    @State private var showAddServiceSheet = false
    @State private var addServiceCode = ""
    @State private var addServiceError: String?
    @State private var isJoiningService = false
    @State private var joinSuccessMessage: String?

    private func loadCurrentTripStartTime() {
        guard let activeGroup = profile?.primaryGroupID, !activeGroup.isEmpty else { return }

        let db = Firestore.firestore()
        db.collection("groups").document(activeGroup)
            .collection("tripEvents")
            .whereField("type", isEqualTo: "started")
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, _ in
                if let doc = snapshot?.documents.first,
                   let ts = doc.data()["createdAt"] as? Timestamp {
                    tripStartTime = ts.dateValue()
                }
            }
    }

    // Build service list from real profile data (no mocks)
    private var allServices: [ServiceDisplay] {
        guard let profile = profile else { return [] }

        var result: [ServiceDisplay] = []

        // Use new multi-group data if available, fallback to legacy
        let groupIDs = profile.groupIDs.isEmpty ? [profile.groupID].compactMap { $0 } : profile.groupIDs
        let activeIDs = profile.activeGroupIDs.isEmpty ? [profile.primaryGroupID].filter { !$0.isEmpty } : profile.activeGroupIDs

        for gid in groupIDs {
            let isActiveGroup = activeIDs.contains(gid)
            let name = (gid == profile.groupID) ? (profile.groupName ?? "Servis") : "Servis \(gid.prefix(6))"

            result.append(ServiceDisplay(
                id: gid,
                name: name,
                isActive: isActiveGroup,
                departure: nil
            ))
        }

        return result
    }

    var body: some View {
        ZStack {
            // Background with grid pattern
            NeonTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Minimal Top Bar - only back button (no title, big title is below)
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(NeonTheme.secondary)
                            .padding(10)
                            .background(NeonTheme.surfaceContainer)
                            .clipShape(Rectangle())
                            .overlay(
                                Rectangle()
                                    .stroke(NeonTheme.secondary.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(NeonTheme.surface.opacity(0.8))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(NeonTheme.primary.opacity(0.2))
                        .frame(height: 1)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SERVİSLERİM")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(NeonTheme.onSurface)
                                .tracking(1)

                            Rectangle()
                                .fill(NeonTheme.primary)
                                .frame(width: 48, height: 4)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Active services (only those in activeGroupIDs AND currently active in store)
                        let activeServices = allServices.filter { service in
                            let isUserActive = profile?.activeGroupIDs.contains(service.id) ?? false
                            return isUserActive && store.isTripActive
                        }

                        // Other registered services (not currently active)
                        let otherServices = allServices.filter { service in
                            let isUserActive = profile?.activeGroupIDs.contains(service.id) ?? false
                            return !isUserActive || !store.isTripActive
                        }

                        // Active Service Card - only when trip is live
                        if !activeServices.isEmpty {
                            ForEach(activeServices) { activeService in
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text("SİSTEM AKTİF")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .tracking(1.5)
                                            .foregroundStyle(NeonTheme.background)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(NeonTheme.secondary)
                                            .clipShape(Rectangle())
                                    }

                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(activeService.name)
                                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                                .foregroundStyle(NeonTheme.secondary)

                                            if let start = tripStartTime {
                                                Text("Başlangıç: \(start.formatted(date: .omitted, time: .shortened))")
                                                    .font(.system(size: 12, design: .rounded))
                                                    .foregroundStyle(NeonTheme.onSurfaceVariant)
                                            } else {
                                                Text("Sürücü servisi başlattı")
                                                    .font(.system(size: 12, design: .rounded))
                                                    .foregroundStyle(NeonTheme.onSurfaceVariant)
                                            }
                                        }

                                        Spacer()

                                        Text("AKTİF")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .tracking(1)
                                            .foregroundStyle(NeonTheme.secondary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(NeonTheme.secondary.opacity(0.15))
                                            .clipShape(Rectangle())
                                            .overlay(
                                                Rectangle()
                                                    .stroke(NeonTheme.secondary.opacity(0.4), lineWidth: 1)
                                            )
                                    }
                                }
                                .padding(20)
                                .background(NeonTheme.surfaceContainerHigh)
                                .clipShape(Rectangle())
                                .overlay(
                                    Rectangle()
                                        .stroke(NeonTheme.secondary.opacity(0.5), lineWidth: 1)
                                )
                                .padding(.horizontal, 24)
                                .onAppear {
                                    loadCurrentTripStartTime()
                                }
                            }
                        }

                        // Registered Routes Section (non-active services go here)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Rectangle()
                                    .fill(NeonTheme.primary)
                                    .frame(width: 3, height: 14)
                                Text("KAYITLI ROTALAR")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .tracking(1.5)
                                    .foregroundStyle(NeonTheme.onSurfaceVariant)
                            }
                            .padding(.horizontal, 24)

                            if !otherServices.isEmpty {
                                VStack(spacing: 12) {
                                    ForEach(otherServices) { service in
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(service.name)
                                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                                    .foregroundStyle(NeonTheme.onSurface)
                                            }

                                            Spacer()

                                            Button(action: {
                                                // TODO: Switch to this service
                                            }) {
                                                Text("GEÇİŞ YAP")
                                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                                    .tracking(0.5)
                                                    .foregroundStyle(NeonTheme.primary)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 8)
                                                    .background(NeonTheme.surfaceContainerHighest)
                                                    .clipShape(Rectangle())
                                                    .overlay(
                                                        Rectangle()
                                                            .stroke(NeonTheme.primary.opacity(0.3), lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(NeonTheme.surfaceContainer)
                                        .clipShape(Rectangle())
                                        .overlay(
                                            Rectangle()
                                                .stroke(NeonTheme.onSurface.opacity(0.06), lineWidth: 1)
                                        )
                                        .padding(.horizontal, 24)
                                    }
                                }
                            } else {
                                // Empty state when the user has no other routes
                                VStack(spacing: 8) {
                                    Text("Başka rota yok")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(NeonTheme.onSurface)

                                    Text("Yeni bir servis ekleyerek rotalarını genişletebilirsin.")
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundStyle(NeonTheme.onSurfaceVariant)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .padding(.horizontal, 16)
                                .background(NeonTheme.surfaceContainer)
                                .clipShape(Rectangle())
                                .overlay(
                                    Rectangle()
                                        .stroke(NeonTheme.outline.opacity(0.3), lineWidth: 1)
                                )
                                .padding(.horizontal, 24)
                            }
                        }

                    }
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if profile?.role == .passenger {
                    Button(action: openAddServiceSheet) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(NeonTheme.primary)

                            Text("YENİ SERVİS EKLE")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .tracking(1)
                                .foregroundStyle(NeonTheme.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(NeonTheme.background)
                        .clipShape(Rectangle())
                        .overlay(
                            Rectangle()
                                .stroke(NeonTheme.primary, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { openSmlerInviteAddServiceIfNeeded() }
        .overlay {
            if showAddServiceSheet {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { closeAddServiceSheet() }

                    AddServiceSheet(
                        serviceCode: Binding(
                            get: { addServiceCode },
                            set: { addServiceCode = $0.uppercased() }
                        ),
                        isLoading: isJoiningService,
                        errorText: addServiceError,
                        onJoin: { Task { await joinNewService() } },
                        onDismiss: { closeAddServiceSheet() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(edges: .bottom)
                .animation(.easeInOut(duration: 0.28), value: showAddServiceSheet)
            }
        }
        .alert("Başarılı", isPresented: Binding(
            get: { joinSuccessMessage != nil },
            set: { if !$0 { joinSuccessMessage = nil } }
        )) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(joinSuccessMessage ?? "")
        }
    }

    private func openSmlerInviteAddServiceIfNeeded() {
        guard openAddServiceOnAppear else { return }
        let code = SmlerConfig.normalizedCode(initialServiceCode)
        guard code.count >= 4 else { return }
        addServiceCode = code
        addServiceError = nil
        showAddServiceSheet = true
    }

    private func openAddServiceSheet() {
        addServiceCode = ""
        addServiceError = nil
        showAddServiceSheet = true
    }

    private func closeAddServiceSheet() {
        showAddServiceSheet = false
        addServiceError = nil
    }

    private func joinNewService() async {
        guard let profile else { return }
        addServiceError = nil
        isJoiningService = true
        defer { isJoiningService = false }

        do {
            let updated = try await store.joinAdditionalGroup(
                code: addServiceCode,
                currentProfile: profile
            )
            session.save(updated)
            store.stopListening()
            store.startListening(groupID: updated.primaryGroupID)
            await NotificationService.shared.saveTokenToProfile(
                groupID: updated.primaryGroupID,
                memberID: updated.memberID
            )
            closeAddServiceSheet()
            joinSuccessMessage = "\(updated.groupName ?? "Servis") eklendi ve aktif yapıldı."
        } catch let error as ShuttleStoreError {
            addServiceError = error.errorDescription
        } catch {
            addServiceError = error.localizedDescription
        }
    }
}

// Helper model for display
struct ServiceDisplay: Identifiable {
    let id: String
    let name: String
    let isActive: Bool
    let departure: String?
}

#Preview {
    MyServicesView()
        .environment(UserSession.shared)
}
