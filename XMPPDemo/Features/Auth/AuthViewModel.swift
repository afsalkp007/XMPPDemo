import SwiftUI
import Observation

@MainActor
@Observable
final class AuthViewModel {

    // MARK: - Input Fields
    var jid      = ""
    var password = ""
    var host     = ""   // Optional — leave empty to derive from JID domain

    // MARK: - UI State
    var isLoading   = false
    var errorMessage: String? = nil
    var fieldErrors: FieldErrors = .init()

    // MARK: - Validation
    struct FieldErrors {
        var jid:      String? = nil
        var password: String? = nil
    }

    var isFormValid: Bool {
        !jid.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty &&
        jid.contains("@")
    }

    // MARK: - Dependencies
    private let env: AppEnvironment

    init(env: AppEnvironment) { self.env = env }

    init() { self.env = AppEnvironment.shared }

    // MARK: - Actions

    func login() async {
        guard validate() else { return }

        isLoading    = true
        errorMessage = nil

        let trimmedJID  = jid.trimmingCharacters(in: .whitespaces).lowercased()
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)

        do {
            try await env.login(
                jid:      trimmedJID,
                password: password,
                host:     trimmedHost.isEmpty ? nil : trimmedHost
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func autoLoginIfCredentialsSaved() async {
        guard let creds = env.savedCredentials else { return }
        jid      = creds.jid
        password = creds.password
        await login()
    }

    // MARK: - Private

    @discardableResult
    private func validate() -> Bool {
        var errors = FieldErrors()
        var isValid = true

        let trimmedJID = jid.trimmingCharacters(in: .whitespaces)
        if trimmedJID.isEmpty {
            errors.jid = "JID is required"
            isValid = false
        } else if !trimmedJID.contains("@") {
            errors.jid = "Must be in user@domain format"
            isValid = false
        }

        if password.isEmpty {
            errors.password = "Password is required"
            isValid = false
        }

        fieldErrors = errors
        return isValid
    }
}
