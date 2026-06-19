//
//  AuthRepository.swift
//  Jesuit
//
//  Concrete implementation of the auth endpoints backed by NetworkService
//  and TokenKeychainActor.
//

import Foundation

/// Envelope for the `signin` / `signup` `data` field. Token keys are probed
/// tolerantly because the captured HAR delivered them via httpOnly cookies
/// (stripped on export); an embedded `user`/`company` is used when present so
/// a follow-up `/auth/me` call can be skipped.
private nonisolated struct AuthSessionData: Codable, Sendable {
    let tokens: AuthTokens
    let user: AuthUser?
    let company: AuthCompany?
    let roles: [String]?
    let permissions: [String]?

    init(from decoder: Decoder) throws {
        // Tokens may sit at the top level or under a "tokens"/"data" object.
        if let direct = try? AuthTokens(from: decoder) {
            tokens = direct
        } else {
            let nested = try decoder.container(keyedBy: AnyCodingKey.self)
            if let key = AnyCodingKey(stringValue: "tokens"),
               let value = try? nested.decode(AuthTokens.self, forKey: key) {
                tokens = value
            } else if let key = AnyCodingKey(stringValue: "data"),
                      let value = try? nested.decode(AuthTokens.self, forKey: key) {
                tokens = value
            } else {
                throw NetworkError.decodingError("Missing tokens in auth response")
            }
        }

        let container = try? decoder.container(keyedBy: AnyCodingKey.self)
        user = container.flatMap { c in
            AnyCodingKey(stringValue: "user").flatMap { try? c.decode(AuthUser.self, forKey: $0) }
        }
        company = container.flatMap { c in
            AnyCodingKey(stringValue: "company").flatMap { try? c.decode(AuthCompany.self, forKey: $0) }
        }
        roles = container.flatMap { c in
            AnyCodingKey(stringValue: "roles").flatMap { try? c.decode([String].self, forKey: $0) }
        }
        permissions = container.flatMap { c in
            AnyCodingKey(stringValue: "permissions").flatMap { try? c.decode([String].self, forKey: $0) }
        }
    }

    func encode(to encoder: Encoder) throws {
        try tokens.encode(to: encoder)
    }
}

struct AuthRepository: AuthRepositoryProtocol {
    private let network: NetworkServiceProtocol

    init(network: NetworkServiceProtocol) {
        self.network = network
    }

    @discardableResult
    func signIn(login: String, password: String) async throws -> AuthMe {
        let response = try await network.request(
            endpoint: Endpoint(path: AppURLConstants.Auth.signIn, method: .post, requiresAuth: false),
            body: SignInRequest(login: login, password: password),
            responseType: AuthSessionData.self
        )
        return try await establishSession(from: response?.data)
    }

    @discardableResult
    func signUp(_ request: SignUpRequest) async throws -> AuthMe {
        let response = try await network.request(
            endpoint: Endpoint(path: AppURLConstants.Auth.signUp, method: .post, requiresAuth: false),
            body: request,
            responseType: AuthSessionData.self
        )
        // signup may return the same session payload as signin; if it doesn't,
        // fall back to an explicit sign-in with the new credentials.
        if let data = response?.data {
            return try await establishSession(from: data)
        }
        return try await signIn(login: request.email, password: request.password)
    }

    func logout() async throws {
        let refresh = try? await TokenKeychainActor.shared.getTokens()?.refresh
        defer { Task { try? await TokenKeychainActor.shared.clear() } }

        guard let refresh else { return }
        _ = try? await network.request(
            endpoint: Endpoint(path: AppURLConstants.Auth.logout, method: .post),
            body: LogoutRequest(refreshToken: refresh),
            responseType: EmptyResponse.self
        )
    }

    func fetchMe() async throws -> AuthMe {
        let response = try await network.request(
            endpoint: Endpoint(path: AppURLConstants.Auth.me, method: .get),
            body: Optional<EmptyResponse>.none,
            responseType: AuthMe.self
        )
        guard let me = response?.data else { throw NetworkError.noData }
        return me
    }

    func fetchCompanies() async throws -> [CompanyDTO] {
        let response = try await network.requestDecoded(
            endpoint: Endpoint(path: AppURLConstants.Auth.companies, method: .get),
            body: Optional<EmptyResponse>.none,
            responseType: CompaniesResponse.self
        )
        return response.data ?? []
    }

    @discardableResult
    func createCompany(_ request: CreateCompanyRequest) async throws -> CompanyDTO? {
        let response = try await network.requestDecoded(
            endpoint: Endpoint(path: AppURLConstants.Core.companies, method: .post),
            body: request,
            responseType: CreateCompanyResponse.self
        )
        return response.data
    }

    @discardableResult
    func updateCompany(id: String, request: CreateCompanyRequest) async throws -> CompanyDTO? {
        let response = try await network.requestDecoded(
            endpoint: Endpoint(path: AppURLConstants.Core.company(id), method: .put),
            body: request,
            responseType: CreateCompanyResponse.self
        )
        return response.data
    }

    func deleteCompany(id: String) async throws {
        // Response is `{ data: null, message }`; CreateCompanyResponse tolerates null data.
        _ = try await network.requestDecoded(
            endpoint: Endpoint(path: AppURLConstants.Core.company(id), method: .delete),
            body: Optional<EmptyResponse>.none,
            responseType: CreateCompanyResponse.self
        )
    }

    @discardableResult
    func switchCompany(to companyId: String) async throws -> AuthMe {
        let response = try await network.request(
            endpoint: Endpoint(path: AppURLConstants.Auth.switchCompany, method: .post),
            body: SwitchCompanyRequest(companyId: companyId),
            responseType: AuthSessionData.self
        )
        return try await establishSession(from: response?.data)
    }

    func changePassword(current: String, new: String) async throws {
        _ = try await network.request(
            endpoint: Endpoint(path: AppURLConstants.Auth.changePassword, method: .put),
            body: ChangePasswordRequest(currentPassword: current, newPassword: new),
            responseType: EmptyResponse.self
        )
    }

    @discardableResult
    func updateProfile(fullName: String, phone: String) async throws -> AuthMe {
        _ = try await network.request(
            endpoint: Endpoint(path: AppURLConstants.Auth.updateProfile, method: .put),
            body: UpdateProfileRequest(fullName: fullName, phone: phone),
            responseType: EmptyResponse.self
        )
        // Re-fetch the canonical profile so the session reflects the new values.
        return try await fetchMe()
    }

    func restoreSession() async -> AuthMe? {
        // No stored tokens — nothing to restore. (`try?` flattens the throwing
        // optional, so the bind fails when the keychain is empty or errors.)
        guard (try? await TokenKeychainActor.shared.getTokens()) != nil else {
            return nil
        }
        do {
            return try await fetchMe()
        } catch NetworkError.unauthorized {
            // Stored token is stale/revoked — clear it so the user lands on login.
            try? await TokenKeychainActor.shared.clear()
            return nil
        } catch {
            // Transient failure (e.g. offline): keep tokens, but stay signed out
            // for this launch.
            return nil
        }
    }

    // MARK: - Helpers

    /// Persists tokens then resolves the profile, preferring an embedded user
    /// and otherwise calling `/auth/me`.
    private func establishSession(from data: AuthSessionData?) async throws -> AuthMe {
        guard let data else { throw NetworkError.noData }
        try await TokenKeychainActor.shared.setTokens(
            accessToken: data.tokens.accessToken,
            refreshToken: data.tokens.refreshToken
        )
        // Use the embedded profile only when the payload also carries the
        // roles/permissions the UI gates on; otherwise fall back to `/auth/me`
        // so we never strip the signed-in user's grants.
        if let user = data.user, data.roles != nil || data.permissions != nil {
            return AuthMe(
                user: user,
                company: data.company,
                roles: data.roles,
                permissions: data.permissions
            )
        }
        return try await fetchMe()
    }
}

/// Placeholder type for endpoints with an empty or ignored response body.
nonisolated struct EmptyResponse: Codable, Sendable {}
