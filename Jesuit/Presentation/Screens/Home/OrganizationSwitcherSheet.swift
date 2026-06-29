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
    @Injected private var navigation: NavigationService
    /// Shared singleton — the same instance the dashboard uses, so switching here
    /// updates Home live.
    @State private var presenter = AppDI.shared.resolver(HomePresenter.self)

    /// Drives the create/edit/subsidiary form page via `.navigationDestination(item:)`.
    /// Hashable by `id` so it can drive a navigation push without making `CompanyDTO` Hashable.
    private enum FormRoute: Identifiable, Hashable {
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

        static func == (lhs: FormRoute, rhs: FormRoute) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }

        var sheetMode: CreateCompanySheet.Mode {
            switch self {
            case .create: return .create
            case .edit(let c): return .edit(c)
            case .subsidiary(let c): return .subsidiary(parent: c)
            }
        }
    }

    @State private var formRoute: FormRoute?
    @State private var deleteTarget: CompanyDTO?

    private var companies: [CompanyDTO] { presenter.companies }
    private var activeCompanyId: String? { presenter.activeCompanyId }
    private var switchingCompanyId: String? { presenter.switchingCompanyId }

    var body: some View {
        // Pushed as a top-level UIPilot route (sibling of MainTabScreen), so it owns
        // its OWN NavigationStack and stays outside the TabView — which is what stops
        // the tab bar blinking on pop.
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
                ToolbarItem(placement: .topBarLeading) {
                    Button { navigation.pop() } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.title)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Kelola") { formRoute = .create }
                        .foregroundStyle(.accent)
                }
            }
            .navigationDestination(item: $formRoute) { route in
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
            .alert("Gagal berpindah", isPresented: switchErrorBinding) {
                Button("OK", role: .cancel) { presenter.switchError = nil }
            } message: {
                Text(presenter.switchError ?? "")
            }
        }
    }

    /// Surfaces the alert while a company switch error is set (cleared on dismissal).
    private var switchErrorBinding: Binding<Bool> {
        Binding(get: { presenter.switchError != nil }, set: { if !$0 { presenter.switchError = nil } })
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
                if await presenter.switchCompany(to: company.id) { navigation.pop() }
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
                        .customFont(.semibold, Typography.body)
                        .foregroundStyle(.accent)
                        .lineLimit(1)
                    Text(company.subtitle)
                        .customFont(.regular, Typography.subhead)
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
