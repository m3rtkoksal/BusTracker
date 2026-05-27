import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

struct NeonOTPInput: View {
    @Binding var code: String
    private let length = 6

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0.01)
                .frame(width: 1, height: 1)

            HStack(spacing: 8) {
                ForEach(0..<length, id: \.self) { index in
                    otpBox(at: index)
                }
            }
            .onTapGesture { isFocused = true }
        }
        .onAppear { isFocused = true }
        .onChange(of: code) { _, newValue in
            code = String(newValue.filter(\.isNumber).prefix(length))
        }
    }

    private func otpBox(at index: Int) -> some View {
        let digit = digit(at: index)
        let isActive = isFocused && index == code.count

        return Text(digit)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(NeonTheme.primary)
            .frame(width: 46, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(NeonTheme.surfaceBright.opacity(0.8))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isActive ? NeonTheme.secondary : NeonTheme.outline.opacity(0.5),
                        lineWidth: isActive ? 1.5 : 1
                    )
            }
            .shadow(color: isActive ? NeonTheme.secondary.opacity(0.35) : .clear, radius: 8)
    }

    private func digit(at index: Int) -> String {
        guard index < code.count else { return "" }
        return String(code[code.index(code.startIndex, offsetBy: index)])
    }
}

struct OTPVerificationView: View {
    let formattedPhone: String
    @Binding var otpCode: String
    let isLoading: Bool
    let onSubmit: () -> Void
    var onResend: (() -> Void)?
    var onDismiss: () -> Void
    var submitButtonTitle: String = "ONAYLA VE OLUŞTUR"

    @State private var ttlSeconds = 120
    @State private var resendCooldown = 34
    @State private var dragOffset: CGFloat = 0
    @State private var keyboardHeight: CGFloat = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        otpPanel
            .offset(y: dragOffset - keyboardHeight)
            .gesture(dismissDragGesture)
            .onChange(of: otpCode) { _, newValue in
                guard newValue.count == 6, !isLoading else { return }
                onSubmit()
            }
            .onReceive(timer) { _ in
                if ttlSeconds > 0 { ttlSeconds -= 1 }
                if resendCooldown > 0 { resendCooldown -= 1 }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                updateKeyboardHeight(from: notification)
            }
    }

    private func updateKeyboardHeight(from notification: Notification) {
        guard
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }

        let screenHeight = UIScreen.main.bounds.height
        let height = max(0, screenHeight - frame.origin.y)
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25

        withAnimation(.easeOut(duration: duration)) {
            keyboardHeight = height
        }
    }

    private var dismissDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 100 || value.predictedEndTranslation.height > 180 {
                    onDismiss()
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    dragOffset = 0
                }
            }
    }

    private var otpPanel: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Capsule()
                    .fill(NeonTheme.surfaceContainerHighest)
                    .frame(width: 48, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                ZStack {
                    Circle()
                        .fill(NeonTheme.secondary.opacity(0.15))
                        .frame(width: 88, height: 88)
                        .blur(radius: 16)
                    Circle()
                        .fill(NeonTheme.surfaceContainerHigh)
                        .frame(width: 80, height: 80)
                        .overlay {
                            Circle()
                                .strokeBorder(NeonTheme.secondary.opacity(0.3), lineWidth: 1)
                        }
                    Image(systemName: "message.badge.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(NeonTheme.secondary)
                        .shadow(color: NeonTheme.secondary.opacity(0.6), radius: 10)
                }
                .padding(.bottom, 24)

                Text("Kod Doğrulama")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(NeonTheme.onSurface)
                    .padding(.bottom, 12)

                phoneMessage
                    .padding(.bottom, 28)

                NeonOTPInput(code: $otpCode)
                    .padding(.bottom, 28)

                submitButton
                    .padding(.bottom, 20)

                resendButton
            }
            .padding(.horizontal, 32)
            .safeAreaPadding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background {
            sheetBackground
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: 40,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 40,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: [NeonTheme.primary.opacity(0.45), NeonTheme.primary.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .shadow(color: NeonTheme.primary.opacity(0.12), radius: 20, y: -6)
        .ignoresSafeArea(edges: [.bottom, .horizontal])
    }

    private var sheetBackground: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 40,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 40,
            style: .continuous
        )
        .fill(NeonTheme.surfaceContainerLow.opacity(0.92))
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 40,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 40,
                style: .continuous
            )
            .fill(.ultraThinMaterial.opacity(0.35))
        }
    }

    private var phoneMessage: some View {
        Text(messageText)
            .font(.subheadline)
            .foregroundStyle(NeonTheme.onSurfaceVariant)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 280)
    }

    private var messageText: AttributedString {
        var text = AttributedString("\(formattedPhone) numarasına tek kullanımlık kod gönderdik.")
        if let range = text.range(of: formattedPhone) {
            text[range].foregroundColor = NeonTheme.secondary.opacity(0.9)
            text[range].font = .system(.subheadline, design: .monospaced)
        }
        return text
    }

    private var submitButton: some View {
        Button(action: onSubmit) {
            Group {
                if isLoading {
                    ProgressView().tint(NeonTheme.primary)
                } else {
                    HStack(spacing: 10) {
                        Text(submitButtonTitle)
                            .tracking(1.5)
                        if submitButtonTitle == "ONAYLA VE OLUŞTUR" {
                            Image(systemName: "bolt.fill")
                        }
                    }
                    .foregroundStyle(NeonTheme.primary)
                    .shadow(color: NeonTheme.primary.opacity(0.5), radius: 6)
                }
            }
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NeonTheme.surfaceContainerHigh)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(NeonTheme.primary.opacity(0.5), lineWidth: 1)
        }
        .disabled(otpCode.count < 6 || isLoading)
        .opacity(otpCode.count >= 6 ? 1 : 0.5)
    }

    private var resendButton: some View {
        Button {
            guard resendCooldown == 0 else { return }
            resendCooldown = 34
            onResend?()
        } label: {
            Text(resendCooldown > 0
                 ? "KODU TEKRAR GÖNDER (\(resendCooldown)S)"
                 : "KODU TEKRAR GÖNDER")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(2)
                .foregroundStyle(resendCooldown > 0 ? NeonTheme.onSurfaceVariant : NeonTheme.secondary)
        }
        .buttonStyle(.plain)
        .disabled(resendCooldown > 0 || onResend == nil)
    }
}

#Preview {
    @Previewable @State var code = "123"
    ZStack(alignment: .bottom) {
        NeonBackgroundView()
        OTPVerificationView(
            formattedPhone: "+90 532 123 45 67",
            otpCode: $code,
            isLoading: false,
            onSubmit: {},
            onResend: {},
            onDismiss: {}
        )
    }
}
