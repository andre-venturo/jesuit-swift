//
//  OrganizationSwitcherSheet.swift
//  Jesuit
//
//  Organisation picker presented from the dashboard header. Lists the companies
//  the signed-in user can act under (holding + subsidiaries) and switches the
//  active one on tap. Styled after the iOS account/organisation picker: a single
//  rounded card of rows, each with an avatar, name, "Type • Role" subtitle and a
//  trailing checkmark on the active org.
//

import SwiftUI

struct OrganizationSwitcherSheet: View {
    let presenter: HomePresenter
    /// Switches to `companyId`; returns `true` on success so the sheet can dismiss.
    let onSelect: (String) async -> Bool

    /// Drives the create/edit/subsidiary form sheet via `.sheet(item:)`.
    private enum FormRoute: Identifiable {
        case create
        case edit(CompanyDTO)
        case subsidiary(CompanyDTO)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let c): return "edit-\(c.id)"
            case .subsidiary(let c): return "sub-\(c.id)"
            }
        }

        var sheetMode: CreateCompanySheet.Mode {
            switch self {
            case .create: return .create
            case .edit(let c): return .edit(c)
            case .subsidiary(let c): return .subsidiary(parent: c)
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var formRoute: FormRoute?
    @State private var deleteTarget: CompanyDTO?

    private var companies: [CompanyDTO] { presenter.companies }
    private var activeCompanyId: String? { presenter.activeCompanyId }
    private var switchingCompanyId: String? { presenter.switchingCompanyId }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(companies.enumerated()), id: \.element.id) { index, company in
                        row(company)
                        RowDivider(index: index, count: companies.count, inset: 72)
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(16)
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Organisasi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batalkan") { dismiss() }
                        .foregroundStyle(.accent)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Kelola") { formRoute = .create }
                        .foregroundStyle(.accent)
                }
            }
            .sheet(item: $formRoute) { route in
                CreateCompanySheet(presenter: presenter, mode: route.sheetMode, onSaved: {})
            }
            .alert("Hapus Perusahaan", isPresented: deleteAlertBinding, presenting: deleteTarget) { company in
                Button("Batal", role: .cancel) {}
                Button("Hapus", role: .destructive) {
                    Task { await presenter.deleteCompany(id: company.id) }
                }
            } message: { company in
                Text("Hapus \(company.name)? Tindakan ini tidak dapat dibatalkan.")
            }
        }
    }

    /// Surfaces the alert while a delete target is set (cleared on dismissal).
    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
    }

    private func row(_ company: CompanyDTO) -> some View {
        let isActive = company.id == activeCompanyId
        let isSwitching = company.id == switchingCompanyId
        let isDeleting = company.id == presenter.deletingCompanyId
        let isBusy = switchingCompanyId != nil || presenter.deletingCompanyId != nil

        return Button {
            guard !isActive, !isBusy else { return }
            Task {
                if await onSelect(company.id) { dismiss() }
            }
        } label: {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.subtitle.opacity(0.4), lineWidth: 1)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "building.2")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.subtitle)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(company.name)
                        .customFont(.semibold, 16)
                        .foregroundStyle(.accent)
                        .lineLimit(1)
                    Text(company.subtitle)
                        .customFont(.regular, 13)
                        .foregroundStyle(.subtitle)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                if isSwitching || isDeleting {
                    ProgressView().tint(.accent)
                } else if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.accent)
                }

                rowMenu(company, isActive: isActive)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isActive || isBusy)
    }

    /// Per-row "…" menu: Edit, add a subsidiary under this company, and (for
    /// non-active companies) Delete.
    private func rowMenu(_ company: CompanyDTO, isActive: Bool) -> some View {
        Menu {
            Button { formRoute = .edit(company) } label: {
                Label("Ubah", systemImage: "pencil")
            }
            Button { formRoute = .subsidiary(company) } label: {
                Label("Anak Perusahaan", systemImage: "plus")
            }
            // The active company can't be deleted (you'd lose your context).
            if !isActive {
                Button(role: .destructive) { deleteTarget = company } label: {
                    Label("Hapus", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.subtitle)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .disabled(presenter.deletingCompanyId != nil || switchingCompanyId != nil)
    }
}
