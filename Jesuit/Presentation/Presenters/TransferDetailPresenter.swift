//
//  TransferDetailPresenter.swift
//  Jesuit
//
//  Presenter for the Transfer Dana detail sheet: loads the full transfer,
//  resolves account/branch names, and runs the status/role-gated actions
//  (Ubah / Setujui / Tolak / Hapus).
//

import SwiftUI
import Observation

@Observable
@MainActor
final class TransferDetailPresenter {
    private let repository: FundTransferRepositoryProtocol
    private let lookups: CashReceiptRepositoryProtocol
    private let session: AuthSession

    let id: String

    private(set) var state: AppState<FundTransferDetail> = .idle
    private(set) var actionState: AppState<Bool> = .idle
    private(set) var activityState: AppState<[ActivityEntry]> = .idle

    private var accounts: [AccountDTO] = []
    private var branches: [BranchDTO] = []

    init(id: String, repository: FundTransferRepositoryProtocol,
         lookups: CashReceiptRepositoryProtocol, session: AuthSession) {
        self.id = id
        self.repository = repository
        self.lookups = lookups
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

    var detail: FundTransferDetail? {
        if case .success(let d) = state { return d }
        return nil
    }

    // MARK: - Activity (Riwayat tab)

    var isLoadingActivity: Bool {
        if case .loading = activityState { return true }
        return false
    }

    var activityErrorMessage: String? {
        if case .error(let error) = activityState { return LoginPresenter.message(for: error) }
        return nil
    }

    var activity: [ActivityEntry] {
        if case .success(let entries) = activityState { return entries }
        return []
    }

    func loadActivity() async {
        switch activityState {
        case .loading, .success: return
        default: break
        }
        activityState = .loading
        do {
            let logs = try await repository.fetchActivity(reffId: id)
            let entries = logs.map(ActivityEntry.init(dto:))
            activityState = entries.isEmpty ? .empty : .success(entries)
        } catch {
            activityState = .error(error)
        }
    }

    // MARK: - Permission / status gating

    private var isCreator: Bool {
        guard let detail else { return false }
        return detail.createdById == session.userId
    }

    var canApproveOrReject: Bool {
        guard let detail else { return false }
        let waiting = detail.rawStatus == "waiting" || detail.rawStatus == "pending"
        return session.can(Permission.cashApprove) && waiting
    }

    var canEdit: Bool {
        guard detail != nil else { return false }
        return session.can(Permission.cashUpdate) || isCreator
    }

    var canDelete: Bool {
        guard detail != nil else { return false }
        return session.can(Permission.cashDelete)
    }

    // MARK: - Load

    func load() async {
        // `detail` derives from `.success`, so don't blank it while re-fetching
        // (pop-back from the pushed edit screen refires .task). The previous
        // detail stays visible until the fresh one lands.
        if detail == nil { state = .loading }
        do {
            async let accountsResult = try? lookups.fetchAssetAccounts()
            async let branchesResult = try? lookups.fetchBranches()
            let dto = try await repository.fetchDetail(id: id)
            accounts = await accountsResult ?? []
            branches = await branchesResult ?? []
            state = .success(map(dto))
        } catch {
            state = .error(error)
        }
    }

    // MARK: - Actions

    @discardableResult
    func approve(comment: String) async -> Bool {
        await run { try await self.repository.approve(id: self.id, comment: comment) }
    }

    @discardableResult
    func reject(reason: String) async -> Bool {
        await run { try await self.repository.reject(id: self.id, reason: reason) }
    }

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

    private func run(_ op: @escaping () async throws -> FundTransferDTO) async -> Bool {
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

    private func map(_ dto: FundTransferDTO) -> FundTransferDetail {
        FundTransferDetail(
            id: dto.id,
            number: dto.transferNo ?? "-",
            date: dto.transferDate ?? dto.createdAt ?? .now,
            description: dto.description ?? "",
            fromAccountId: dto.fromAccountId,
            fromAccountName: accountName(dto.fromAccountId),
            fromBranchName: branchName(dto.fromBranchId),
            toAccountId: dto.toAccountId,
            toAccountName: accountName(dto.toAccountId),
            toBranchName: branchName(dto.toBranchId),
            amount: dto.amount ?? 0,
            currencyCode: "IDR",
            fromCurrencyCode: dto.fromCurrencyCode ?? "IDR",
            toCurrencyCode: dto.toCurrencyCode ?? "IDR",
            exchangeRate: dto.exchangeRate ?? 1,
            originalAmount: dto.originalAmount ?? 0,
            status: ReceiptStatus(apiStatus: dto.status),
            rawStatus: (dto.status ?? "").lowercased(),
            approvalLevel: dto.currentApprovalLevel,
            totalApprovalLevels: dto.totalApprovalLevels,
            hasJournal: !(dto.journalEntryId ?? "").isEmpty,
            createdAt: dto.createdAt ?? .now,
            createdById: dto.createdBy,
            updatedAt: dto.updatedAt ?? dto.createdAt ?? .now,
            attachments: (dto.attachments ?? []).compactMap { att in
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
}
