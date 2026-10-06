import SwiftUI

struct LoginView: View {
    @State private var vm = AuthViewModel()

    @State private var showPassword     = false
    @State private var showAdvanced     = false
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var formOffset: CGFloat = 40
    @State private var formOpacity: Double = 0

    var body: some View {
        ZStack {
            // MARK: Background
            LinearGradient.loginHero
                .ignoresSafeArea()

            // Ambient glow orbs
            GeometryReader { geo in
                Circle()
                    .fill(Color.brandCyan.opacity(0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: geo.size.width * 0.5 - 160, y: -60)

                Circle()
                    .fill(Color.brandCyanDeep.opacity(0.10))
                    .frame(width: 240, height: 240)
                    .blur(radius: 60)
                    .offset(x: 20, y: geo.size.height * 0.55)
            }
            .ignoresSafeArea()

            // MARK: Content
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    // Logo
                    logoSection
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    Spacer(minLength: 52)

                    // Form card
                    formCard
                        .offset(y: formOffset)
                        .opacity(formOpacity)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear { animateEntrance() }
        .task { await vm.autoLoginIfCredentialsSaved() }
    }

    // MARK: - Logo

    private var logoSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient.brand)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.brandCyan.opacity(0.5), radius: 20)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text("XMPPDemo")
                    .font(.appLargeTitle)
                    .foregroundStyle(.textPrimary)

                Text("Secure messaging over XMPP")
                    .font(.appSubheadline)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 20) {

            // JID field
            VStack(alignment: .leading, spacing: 6) {
                Label("Jabber ID", systemImage: "person.fill")
                    .font(.appCaption)
                    .foregroundStyle(.textSecondary)

                HStack {
                    Image(systemName: "at")
                        .foregroundStyle(.textTertiary)
                        .frame(width: 20)

                    TextField("user@domain.com", text: $vm.jid)
                        .font(.appBody)
                        .foregroundStyle(.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .submitLabel(.next)
                }
                .padding(14)
                .background(Color.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            vm.fieldErrors.jid != nil ? Color.errorRed.opacity(0.6) : Color.bgBorder,
                            lineWidth: 1
                        )
                )

                if let err = vm.fieldErrors.jid {
                    Text(err)
                        .font(.appCaption2)
                        .foregroundStyle(.errorRed)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Password field
            VStack(alignment: .leading, spacing: 6) {
                Label("Password", systemImage: "lock.fill")
                    .font(.appCaption)
                    .foregroundStyle(.textSecondary)

                HStack {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.textTertiary)
                        .frame(width: 20)

                    if showPassword {
                        TextField("Password", text: $vm.password)
                            .font(.appBody)
                            .foregroundStyle(.textPrimary)
                            .textContentType(.password)
                            .submitLabel(.go)
                    } else {
                        SecureField("Password", text: $vm.password)
                            .font(.appBody)
                            .foregroundStyle(.textPrimary)
                            .textContentType(.password)
                            .submitLabel(.go)
                    }

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(.textTertiary)
                    }
                }
                .padding(14)
                .background(Color.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            vm.fieldErrors.password != nil ? Color.errorRed.opacity(0.6) : Color.bgBorder,
                            lineWidth: 1
                        )
                )

                if let err = vm.fieldErrors.password {
                    Text(err)
                        .font(.appCaption2)
                        .foregroundStyle(.errorRed)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Advanced: custom host
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showAdvanced.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Advanced")
                            .font(.appCaption)
                            .foregroundStyle(.textSecondary)
                        Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.textSecondary)
                    }
                }

                if showAdvanced {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.textTertiary)
                            .frame(width: 20)

                        TextField("Custom host (optional)", text: $vm.host)
                            .font(.appBody)
                            .foregroundStyle(.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                    .padding(14)
                    .background(Color.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.bgBorder, lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Error banner
            if let error = vm.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.errorRed)
                    Text(error)
                        .font(.appCaption)
                        .foregroundStyle(.errorRed)
                    Spacer()
                }
                .padding(12)
                .background(Color.errorRed.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Login button
            Button {
                Task { await vm.login() }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient.brand)
                        .shadow(color: Color.brandCyan.opacity(0.35), radius: 12, y: 4)

                    if vm.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Text("Sign In")
                            .font(.appBodyMedium)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .disabled(vm.isLoading || !vm.isFormValid)
            .opacity(vm.isFormValid ? 1 : 0.55)
            .animation(.easeInOut(duration: 0.2), value: vm.isFormValid)

            // Footer
            Text("Your credentials are stored securely in Keychain and only sent over TLS.")
                .font(.appCaption2)
                .foregroundStyle(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.bgSurface.opacity(0.85))
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.bgBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Entrance Animation

    private func animateEntrance() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.80).delay(0.25)) {
            formOffset  = 0
            formOpacity = 1.0
        }
    }
}

#Preview {
    LoginView()
        .environment(AppEnvironment.shared)
}
