//
//  CashReceiptDetailPresenter.swift
//  Jesuit
//
//  Presenter for the Penerimaan (cash receipt) detail sheet: loads the full
//  transaction, resolves account/branch names, and runs the role- and
//  status-gated actions (Ubah / Setujui / Tolak / Hapus).
//

import SwiftUI
import Observation

@Observable
@MainActor
final class CashReceiptDetailPresenter {
    private let repository: CashReceiptRepositoryProtocol
    private let session: AuthSession

    /// Transaction id being shown.
    let id: String

    private(set) var state: AppState<CashReceiptDetail> = .idle
    /// In-flight action (approve/reject/delete/update) → drives a busy overlay.
    private(set) var actionState: AppState<Bool> = .idle

    private var accounts: [AccountDTO] = []
    private var branches: [BranchDTO] = []

    init(id: String, repository: CashReceiptRepositoryProtocol, session: AuthSession) {
        self.id = id
        self.repository = repository
        self.session = session
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var isWorking: Bool {
        if case .loading = actionState { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let error) = state { return LoginPresenter.message(for: error) }
        return nil
    }

    var actionErrorMessage: String? {
        if case .error(let error) = actionState { return LoginPresenter.message(for: error) }
        return nil
    }

    var detail: CashReceiptDetail? {
        if case .success(let d) = state { return d }
        return nil
    }

    // MARK: - Role / status gating

    private var isAdmin: Bool { session.isAdministrator }

    /// Raw API statuses that are still mutable (not yet finalised). Gating on the
    /// raw string — not the lossy `ReceiptStatus` — so a posted/rejected/unknown
    /// status can never fall through to a permissive default.
    private static let mutableStatuses: Set<String> = ["draft", "waiting", "pending"]

    private var isMutable: Bool {
        guard let detail else { return false }
        return Self.mutableStatuses.contains(detail.rawStatus)
    }

    private var isCreator: Bool {
        guard let detail else { return false }
        return detail.createdById == session.userId
    }

    /// Approve/reject only make sense while waiting for approval, and only for
    /// users who can approve (administrator).
    var canApproveOrReject: Bool {
        guard let detail else { return false }
        let waiting = detail.rawStatus == "waiting" || detail.rawStatus == "pending"
        return isAdmin && waiting
    }

    /// Edit is allowed only on not-yet-finalised transactions (draft / waiting)
    /// for admins or the creator — a posted/rejected entry is locked.
    var canEdit: Bool {
        isMutable && (isAdmin || isCreator)
    }

    /// Delete is allowed in any status (including approved/rejected) for admins
    /// or the creator.
    var canDelete: Bool {
        guard detail != nil else { return false }
        return isAdmin || isCreator
    }

    // MARK: - Load

    func load() async {
        state = .loading
        do {
            // Names for the cash account, counter accounts and branch.
            async let accountsResult = try? repository.fetchCashAccounts()
            async let branchesResult = try? repository.fetchBranches()
            let dto = try await repository.fetchDetail(id: id)
            accounts = await accountsResult ?? []
            branches = await branchesResult ?? []
            state = .success(map(dto))
        } catch {
            state = .error(error)
        }
    }

    // MARK: - Actions

    /// Returns true on success so the caller can show feedback / dismiss.
    @discardableResult
    func approve(comment: String) async -> Bool {
        await run { try await self.repository.approve(id: self.id, comment: comment) }
    }

    @discardableResult
    func reject(reason: String) async -> Bool {
        await run { try await self.repository.reject(id: self.id, reason: reason) }
    }

    /// Deletes the transaction. Returns true on success (caller dismisses + reloads list).
    @discardableResult
    func delete() async -> Bool {
        actionState = .loading
        do {
            try await repository.delete(id: id)
            actionState = .success(true)
            return true
        } catch {
            actionState = .error(error)
            return false
        }
    }

    /// Shared runner for approve/reject: refreshes the shown detail from the
    /// returned DTO.
    private func run(_ op: @escaping () async throws -> CashTransactionDetailDTO) async -> Bool {
        actionState = .loading
        do {
            let dto = try await op()
            state = .success(map(dto))
            actionState = .success(true)
            return true
        } catch {
            actionState = .error(error)
            return false
        }
    }

    // MARK: - Mapping

    private func accountName(_ id: String?) -> String {
        guard let id else { return "—" }
        if let acc = accounts.first(where: { $0.id == id }) {
            return acc.code.map { "\($0) — \(acc.name)" } ?? acc.name
        }
        return "—"
    }

    private func branchName(_ id: String?) -> String {
        guard let id else { return "" }
        return branches.first(where: { $0.id == id })?.name ?? ""
    }

    private func map(_ dto: CashTransactionDetailDTO) -> CashReceiptDetail {
        let lines: [CashReceiptLine] = (dto.lines ?? [])
            .sorted { ($0.lineNumber ?? 0) < ($1.lineNumber ?? 0) }
            .map { line in
                CashReceiptLine(
                    id: line.id,
                    lineNumber: line.lineNumber ?? 0,
                    accountId: line.accountId,
                    accountName: accountName(line.accountId),
                    description: line.description ?? "",
                    amount: line.amount ?? 0,
                    isPinned: line.isPinned ?? false,
                    attachments: (line.attachments ?? []).compactMap { att in
                        guard let url = att.fileUrl, !url.isEmpty else { return nil }
                        return CashLineAttachment(
                            id: att.id,
                            fileName: att.fileName ?? "Lampiran",
                            fileUrl: url,
                            fileSize: att.fileSize ?? 0,
                            mimeType: att.mimeType ?? ""
                        )
                    }
                )
            }
        return CashReceiptDetail(
            id: dto.id,
            number: dto.transactionNo ?? "-",
            date: dto.transactionDate ?? dto.createdAt ?? .now,
            description: dto.description ?? "",
            cashAccountId: dto.cashAccountId,
            cashAccountName: accountName(dto.cashAccountId),
            branchName: branchName(dto.branchId),
            total: dto.totalAmount ?? 0,
            status: ReceiptStatus(apiStatus: dto.status),
            rawStatus: (dto.status ?? "").lowercased(),
            approvalLevel: dto.currentApprovalLevel,
            totalApprovalLevels: dto.totalApprovalLevels,
            hasJournal: !(dto.journalEntryId ?? "").isEmpty,
            createdAt: dto.createdAt ?? .now,
            createdById: dto.createdBy,
            updatedAt: dto.updatedAt ?? dto.createdAt ?? .now,
            lines: lines
        )
    }
}
