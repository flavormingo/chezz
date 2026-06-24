import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @State private var showAuth = false
    @State private var showDiscovery = false
    @State private var showEditProfile = false
    @State private var photoItem: PhotosPickerItem?
    @State private var uploadingPhoto = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    if let user = session.currentUser {
                        header(user)
                        discoverabilityCard(user)
                    } else {
                        SignInPromptCard(
                            title: "Your profile",
                            message: "Sign in to claim a username, track your rating and play online.",
                            icon: "face.smiling",
                            onSignIn: { showAuth = true })
                    }
                    NavigationLink { SettingsView() } label: { settingsRow }
                    if session.isSignedIn {
                        Button { Task { await session.signOut() } } label: {
                            Text("Sign out").font(.chezzHeadline).foregroundStyle(Palette.danger)
                                .frame(maxWidth: .infinity).padding(.vertical, 15)
                                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .strokeBorder(Palette.danger.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.md)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Palette.mint)
        .sheet(isPresented: $showAuth) { AuthView() }
        .sheet(isPresented: $showEditProfile) { EditProfileSheet() }
        .sheet(isPresented: $showDiscovery) { DiscoveryPhoneSheet() }
        .onChange(of: photoItem) { _, item in
            if let item { Task { await uploadPhoto(item) } }
        }
    }

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        uploadingPhoto = true
        defer { uploadingPhoto = false; photoItem = nil }
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let jpeg = Self.downscaledJPEG(raw) else { return }
        try? await session.uploadAvatar(jpeg)
    }

    private static func downscaledJPEG(_ data: Data, maxEdge: CGFloat = 512) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxEdge ? maxEdge / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: target).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }

    private func discoverabilityCard(_ user: UserProfile) -> some View {
        Button { showDiscovery = true } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: user.hasDiscoveryPhone ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle.badge.questionmark")
                    .foregroundStyle(user.hasDiscoveryPhone ? Palette.mint : Palette.textSecondary)
                    .frame(width: 36, height: 36).background(Palette.surface2, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Findable by friends").font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
                    Text(user.hasDiscoveryPhone ? "On. Friends with your number can find you." : "Off. Add your number to be found from contacts.")
                        .font(.chezzCaption).foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Palette.textTertiary)
            }
            .padding(Spacing.md).chezzCard(fill: Palette.surface, radius: Radius.md)
        }
        .buttonStyle(.plain)
    }

    private func header(_ user: UserProfile) -> some View {
        VStack(spacing: Spacing.sm) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Avatar(name: user.name, colorHex: user.avatarColor, size: 72,
                       imageURL: user.imageURL.flatMap { URL(string: $0) })
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.onAccent)
                            .frame(width: 26, height: 26).background(Palette.mint, in: Circle())
                            .overlay(Circle().strokeBorder(Palette.surface, lineWidth: 2))
                    }
                    .overlay {
                        if uploadingPhoto {
                            ZStack { Circle().fill(.black.opacity(0.45)); ProgressView().tint(.white) }
                        }
                    }
            }
            .buttonStyle(.plain)
            Text(user.name).font(.chezzTitle).foregroundStyle(Palette.textPrimary)
            Text("@\(user.username)").font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
            Text("Rating \(user.rating)").font(.chezzCallout).foregroundStyle(Palette.mint)
            HStack(spacing: Spacing.sm) {
                Button("Edit Profile") { showEditProfile = true }
                    .buttonStyle(ChezzSecondaryButtonStyle())
                ShareLink(item: "Add me on Chezz! My username is @\(user.username)") {
                    Text("Share Profile")
                }
                .buttonStyle(ChezzSecondaryButtonStyle())
            }
            .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity).padding(Spacing.lg).chezzCard()
    }

    private var settingsRow: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "gearshape.fill").foregroundStyle(Palette.textSecondary)
                .frame(width: 36, height: 36).background(Palette.surface2, in: Circle())
            Text("Settings").font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Palette.textTertiary)
        }
        .padding(Spacing.md).chezzCard(fill: Palette.surface, radius: Radius.md)
    }
}

struct DiscoveryPhoneSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var phone = ""
    @State private var busy = false
    @State private var error: String?

    private var isDiscoverable: Bool { session.currentUser?.hasDiscoveryPhone ?? false }
    // Loose gate only; the server validates properly with libphonenumber + region. No "+" required.
    private var valid: Bool { phone.filter(\.isNumber).count >= 7 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Let friends who have your number find you on Chezz. Your number is hashed, never shown and never shared. You can remove it anytime.")
                        .font(.chezzSubhead).foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if isDiscoverable {
                        Label("You're findable from contacts", systemImage: "checkmark.circle.fill")
                            .font(.chezzCallout).foregroundStyle(Palette.mint)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your phone number").font(.chezzCaption).foregroundStyle(Palette.textTertiary)
                        TextField("(555) 123-4567", text: $phone)
                            .keyboardType(.phonePad).textContentType(.telephoneNumber)
                            .padding(Spacing.sm).background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.sm))
                            .foregroundStyle(Palette.textPrimary)
                    }
                    Button { Task { await save() } } label: {
                        if busy { ProgressView().tint(Palette.onAccent) } else { Text(isDiscoverable ? "Update number" : "Make me findable") }
                    }
                    .buttonStyle(ChezzPrimaryButtonStyle(enabled: valid)).disabled(!valid || busy)
                    if isDiscoverable {
                        Button("Remove my number", role: .destructive) { Task { await remove() } }
                            .font(.chezzCallout).foregroundStyle(Palette.danger).frame(maxWidth: .infinity)
                    }
                    if let error { Text(error).font(.chezzCaption).foregroundStyle(Palette.danger) }
                }
                .padding(Spacing.lg)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle("Findable by friends").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.foregroundStyle(Palette.textSecondary) } }
        }
        .presentationDetents([.medium, .large]).preferredColorScheme(.dark)
    }

    private func save() async {
        busy = true; error = nil
        do { try await session.setDiscoveryPhone(phone.trimmingCharacters(in: .whitespaces), region: ContactsService.region); dismiss() }
        catch { self.error = (error as? APIError)?.message ?? "Couldn't save your number." }
        busy = false
    }
    private func remove() async {
        busy = true; error = nil
        do { try await session.clearDiscoveryPhone(); dismiss() }
        catch { self.error = (error as? APIError)?.message ?? "Couldn't remove your number." }
        busy = false
    }
}

struct EditProfileSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var available: Bool?
    @State private var savingUsername = false
    @State private var usernameError: String?
    @State private var usernameMessage: String?

    @State private var newEmail = ""
    @State private var emailCode = ""
    @State private var codeSent = false
    @State private var emailBusy = false
    @State private var emailMessage: String?
    @State private var emailError: String?

    private var currentUsername: String { session.currentUser?.username ?? "" }
    private var changedUsername: Bool { username.lowercased() != currentUsername.lowercased() }
    private var usernameValid: Bool {
        let n = username.lowercased()
        return n.count >= 2 && n.count <= 20 && n.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
    }
    private var canSaveUsername: Bool {
        usernameValid && changedUsername && (available ?? false) && !savingUsername
    }
    private var emailValid: Bool {
        let e = newEmail.trimmingCharacters(in: .whitespaces)
        return e.contains("@") && e.contains(".") && e.count >= 6
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    usernameCard
                    emailCard
                }
                .padding(Spacing.md)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .navigationTitle("Edit Profile").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.foregroundStyle(Palette.mint) } }
            .tint(Palette.mint)
        }
        .preferredColorScheme(.dark)
        .onAppear { if username.isEmpty { username = currentUsername } }
    }

    private var usernameCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Username").font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
            HStack(spacing: Spacing.xs) {
                Text("@").foregroundStyle(Palette.textTertiary)
                TextField("username", text: $username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .foregroundStyle(Palette.textPrimary)
                    .onChange(of: username) { _, _ in checkAvailability() }
                if changedUsername, let available {
                    Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(available ? Palette.mint : Palette.danger)
                }
            }
            .padding(Spacing.sm)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.sm))
            statusLine(error: usernameError, success: usernameMessage)
            Button { Task { await saveUsername() } } label: {
                if savingUsername { ProgressView().tint(Palette.onAccent) } else { Text("Save username") }
            }
            .buttonStyle(ChezzPrimaryButtonStyle(enabled: canSaveUsername))
            .disabled(!canSaveUsername)
        }
        .padding(Spacing.md).chezzCard()
    }

    private var emailCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Email").font(.chezzHeadline).foregroundStyle(Palette.textPrimary)
            Text(codeSent ? "Enter the code we sent to \(newEmail)."
                          : "We'll email a code to your new address to confirm it.")
                .font(.chezzCaption).foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !codeSent {
                TextField("new@email.com", text: $newEmail)
                    .keyboardType(.emailAddress).textContentType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .foregroundStyle(Palette.textPrimary)
                    .padding(Spacing.sm)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.sm))
                statusLine(error: emailError, success: emailMessage)
                Button { Task { await sendEmailCode() } } label: {
                    if emailBusy { ProgressView().tint(Palette.onAccent) } else { Text("Send code") }
                }
                .buttonStyle(ChezzPrimaryButtonStyle(enabled: emailValid))
                .disabled(!emailValid || emailBusy)
            } else {
                TextField("123456", text: $emailCode)
                    .keyboardType(.numberPad).textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center).font(.chezzClock(24))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(Spacing.sm)
                    .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.sm))
                statusLine(error: emailError, success: nil)
                Button { Task { await verifyEmailCode() } } label: {
                    if emailBusy { ProgressView().tint(Palette.onAccent) } else { Text("Verify and update") }
                }
                .buttonStyle(ChezzPrimaryButtonStyle(enabled: emailCode.count >= 4))
                .disabled(emailCode.count < 4 || emailBusy)
                Button("Use a different email") { codeSent = false; emailCode = ""; emailError = nil }
                    .font(.chezzCallout).foregroundStyle(Palette.textSecondary).frame(maxWidth: .infinity)
            }
        }
        .padding(Spacing.md).chezzCard()
    }

    @ViewBuilder
    private func statusLine(error: String?, success: String?) -> some View {
        if let error {
            Label(error, systemImage: "exclamationmark.circle.fill")
                .font(.chezzCaption).foregroundStyle(Palette.danger)
        } else if let success {
            Label(success, systemImage: "checkmark.circle.fill")
                .font(.chezzCaption).foregroundStyle(Palette.mint)
        }
    }

    private func checkAvailability() {
        available = nil; usernameMessage = nil; usernameError = nil
        guard usernameValid, changedUsername else { return }
        let name = username
        Task {
            let ok = try? await session.usernameAvailable(name)
            if name == username { available = ok }
        }
    }
    private func saveUsername() async {
        savingUsername = true; usernameError = nil; usernameMessage = nil
        do { try await session.setUsername(username); usernameMessage = "Username updated." }
        catch { usernameError = (error as? APIError)?.message ?? "Couldn't save username." }
        savingUsername = false
    }
    private func sendEmailCode() async {
        emailBusy = true; emailError = nil; emailMessage = nil
        do { try await session.startEmailChange(newEmail.trimmingCharacters(in: .whitespaces)); codeSent = true }
        catch { emailError = (error as? APIError)?.message ?? "Couldn't send the code." }
        emailBusy = false
    }
    private func verifyEmailCode() async {
        emailBusy = true; emailError = nil
        do {
            try await session.verifyEmailChange(emailCode.trimmingCharacters(in: .whitespaces))
            emailMessage = "Email updated."; codeSent = false; newEmail = ""; emailCode = ""
        } catch { emailError = (error as? APIError)?.message ?? "Couldn't verify the code." }
        emailBusy = false
    }
}
