import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    enum Step { case entry, code, username }
    @State private var step: Step = .entry
    @State private var email = ""
    @State private var code = ""
    @State private var username = ""
    @State private var rawNonce = AppleNonce.random()
    @State private var error: String?
    @State private var busy = false
    @State private var available: Bool?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    header
                    switch step {
                    case .entry: entryStep
                    case .code: codeStep
                    case .username: usernameStep
                    }
                    if let error { errorLabel(error) }
                }
                .padding(Spacing.lg)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step != .username { Button("Cancel") { dismiss() }.foregroundStyle(Palette.textSecondary) }
                }
            }
            .interactiveDismissDisabled(busy)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "crown.fill").font(.system(size: 30)).foregroundStyle(Palette.gold)
            Text("Welcome to Chezz").font(.chezzTitle2).foregroundStyle(Palette.textPrimary)
            Text("Sign in to play friends, sync across devices and keep your games.")
                .font(.chezzCaption).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.sm)
    }

    private var entryStep: some View {
        VStack(spacing: Spacing.md) {
            SignInWithAppleButton(.continue) { request in
                rawNonce = AppleNonce.random()
                request.requestedScopes = [.fullName]
                request.nonce = AppleNonce.sha256(rawNonce)
            } onCompletion: { result in
                handleApple(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

            HStack { line; Text("or").font(.chezzCaption).foregroundStyle(Palette.textTertiary); line }

            VStack(alignment: .leading, spacing: 6) {
                Text("Email").font(.chezzCaption).foregroundStyle(Palette.textTertiary)
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress).textContentType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(Spacing.sm)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.sm))
                    .foregroundStyle(Palette.textPrimary)
                Text("We'll email you a 6-digit code. No password needed.")
                    .font(.chezzCaption).foregroundStyle(Palette.textTertiary)
            }
            Button { Task { await sendCode() } } label: {
                if busy { ProgressView().tint(Palette.onAccent) } else { Text("Email me a code") }
            }
            .buttonStyle(ChezzPrimaryButtonStyle(enabled: emailValid))
            .disabled(!emailValid || busy)
        }
        .padding(Spacing.md).chezzCard()
    }

    private var codeStep: some View {
        VStack(spacing: Spacing.md) {
            Text("Enter the code we emailed to \(email)").font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            TextField("123456", text: $code)
                .keyboardType(.numberPad).textContentType(.oneTimeCode)
                .multilineTextAlignment(.center).font(.chezzClock(28))
                .padding(Spacing.sm)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.sm))
                .foregroundStyle(Palette.textPrimary)
            Button { Task { await verify() } } label: {
                if busy { ProgressView().tint(Palette.onAccent) } else { Text("Verify") }
            }
            .buttonStyle(ChezzPrimaryButtonStyle(enabled: code.count >= 4))
            .disabled(code.count < 4 || busy)
            Button("Use a different email") { step = .entry; code = ""; error = nil }
                .font(.chezzCallout).foregroundStyle(Palette.textSecondary)
        }
        .padding(Spacing.md).chezzCard()
    }

    private var usernameStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Pick a username").font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
            Text("This is how friends find and challenge you.").font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
            HStack {
                Text("@").foregroundStyle(Palette.textTertiary)
                TextField("magnus", text: $username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .foregroundStyle(Palette.textPrimary)
                    .onChange(of: username) { _, _ in checkAvailability() }
                if let available {
                    Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(available ? Palette.mint : Palette.danger)
                }
            }
            .padding(Spacing.sm).background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.sm))

            Button { Task { await claimUsername() } } label: {
                if busy { ProgressView().tint(Palette.onAccent) } else { Text("Continue") }
            }
            .buttonStyle(ChezzPrimaryButtonStyle(enabled: usernameValid))
            .disabled(!usernameValid || busy)
        }
        .padding(Spacing.md).chezzCard()
    }

    private func sendCode() async {
        busy = true; error = nil
        do { try await session.sendEmailCode(email.trimmingCharacters(in: .whitespaces)); step = .code }
        catch { self.error = (error as? APIError)?.message ?? error.localizedDescription }
        busy = false
    }

    private func verify() async {
        busy = true; error = nil
        do { try await session.verifyEmailCode(email: email.trimmingCharacters(in: .whitespaces), code: code); afterAuth() }
        catch { self.error = (error as? APIError)?.message ?? "Invalid or expired code." }
        busy = false
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                error = "Could not read Apple credentials."; return
            }
            Task {
                busy = true; error = nil
                do { try await session.signInWithApple(idToken: token, nonce: rawNonce); afterAuth() }
                catch { self.error = (error as? APIError)?.message ?? error.localizedDescription }
                busy = false
            }
        case .failure(let err):
            if (err as? ASAuthorizationError)?.code != .canceled { error = err.localizedDescription }
        }
    }

    private func claimUsername() async {
        busy = true; error = nil
        do { try await session.setUsername(username); afterAuth() }
        catch { self.error = (error as? APIError)?.message ?? "Couldn't set username." }
        busy = false
    }

    private func afterAuth() {
        if session.isSignedIn {
            if session.needsUsername { step = .username } else { dismiss() }
        }
    }

    private func checkAvailability() {
        available = nil
        guard usernameValid else { return }
        let name = username
        Task {
            let ok = try? await session.usernameAvailable(name)
            if name == username { available = ok }
        }
    }

    private var emailValid: Bool {
        let e = email.trimmingCharacters(in: .whitespaces)
        return e.contains("@") && e.contains(".") && e.count >= 6
    }
    private var usernameValid: Bool {
        let n = username.lowercased()
        return n.count >= 3 && n.count <= 20 && n.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
    }
    private var stepTitle: String { step == .username ? "Username" : "Sign in" }
    private var line: some View { Rectangle().fill(Palette.hairline).frame(height: 1) }
    private func errorLabel(_ msg: String) -> some View {
        Text(msg).font(.chezzCaption).foregroundStyle(Palette.danger).frame(maxWidth: .infinity, alignment: .leading)
    }
}
