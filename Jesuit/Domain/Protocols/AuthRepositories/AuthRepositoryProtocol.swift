//
//  AuthRepositoryProtocol.swift
//  Jesuit
//
//  Abstraction over the wizhub auth endpoints.
//

import Foundation

protocol AuthRepositoryProtocol: Sendable {
    /// Signs in with an email/username (`login`) and password, persisting tokens.
    @discardableResult
    func signIn(login: String, password: String) async throws -> AuthMe

    /// Registers a new account. The backend signs the user in on success.
    @discardableResult
    func signUp(_ request: SignUpRequest) async throws -> AuthMe

    /// Revokes the stored refresh token and clears local credentials.
    func logout() async throws

    /// Fetches the currently authenticated user's profile.
    func fetchMe() async throws -> AuthMe

    /// Restores a session from locally stored tokens on launch.
    ///
    /// Returns the profile when valid tokens exist and `/auth/me` succeeds;
    /// returns `nil` (clearing any stale credentials) when there are no tokens
    /// or the stored token is rejected.
    func restoreSession() async -> AuthMe?

    /// Lists the companies the signed-in user can act under (holding +
    /// subsidiaries), for the header company switcher.
    func fetchCompanies() async throws -> [CompanyDTO]

    /// Creates a company (holding or subsidiary) and returns the created record.
    @discardableResult
    func createCompany(_ request: CreateCompanyRequest) async throws -> CompanyDTO?

    /// Updates a company's name/type/parent and returns the updated record.
    @discardableResult
    func updateCompany(id: String, request: CreateCompanyRequest) async throws -> CompanyDTO?

    /// Deletes a company.
    func deleteCompany(id: String) async throws

    /// Switches the active company, persisting the freshly-issued tokens, and
    /// returns the updated profile.
    @discardableResult
    func switchCompany(to companyId: String) async throws -> AuthMe

    /// Changes the signed-in user's password. Throws `NetworkError.serverError`
    /// with the backend message on a wrong current password / weak new one.
    func changePassword(current: String, new: String) async throws

    /// Updates the signed-in user's profile (full name + phone) and returns the
    /// refreshed profile.
    @discardableResult
    func updateProfile(fullName: String, phone: String) async throws -> AuthMe
}
