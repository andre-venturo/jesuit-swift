//
//  CreateCompanySheet.swift
//  Jesuit
//
//  "Perusahaan Baru" — create-company form opened from the organisation
//  switcher's "Kelola" button. Posts to POST /core/v1/companies with
//  { name, type, parent_id }.
//

import SwiftUI

struct CreateCompanySheet: View {
    /// How the sheet seeds the form on appear.
    enum Mode {
        case create
        case edit(CompanyDTO)
        /// New subsidiary with `parent` preselected.
        case subsidiary(parent: CompanyDTO)
    }

    let presenter: HomePresenter
    let mode: Mode
    /// Called after a company is created/updated so the caller can refresh.
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(presenter: HomePresenter, mode: Mode = .create, onSaved: @escaping () -> Void) {
        self.presenter = presenter
        self.mode = mode
        self.onSaved = onSaved
    }

    private var form: HomePresenter.CreateCompanyForm { presenter.companyForm }
    private var isEditing: Bool { if case .edit = mode { return true }; return false }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    nameField
                    typeAndParent

                    if let error = form.errorMessage {
                        Text(error)
                            .customFont(.medium, Typography.callout)
                            .foregroundStyle(.expense)
                    }

                    saveButton
                }
                .padding(20)
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle(isEditing ? "Ubah Perusahaan" : "Perusahaan Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                        .foregroundStyle(.subtitle)
                }
            }
        }
        .task {
            switch mode {
            case .create:
                presenter.startCreateCompany()
            case .edit(let company):
                presenter.startEditCompany(company)
            case .subsidiary(let parent):
                presenter.startCreateSubsidiary(under: parent)
            }
        }
    }

    // MARK: - Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Nama Perusahaan")
            TextField(
                "",
                text: bindName,
                prompt: Text("PT Contoh Indonesia").foregroundStyle(Color.subtitle)
            )
            .font(.customFont(.regular, Typography.body))
            .foregroundStyle(Color.title)
            .textInputAutocapitalization(.words)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.textFieldBG)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Type + Parent

    private var typeAndParent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                typeMenu
                parentMenu
            }

            Text(form.type == .holding
                 ? "Holding adalah perusahaan tingkat atas tanpa induk."
                 : "Anak perusahaan harus memilih induk holding.")
                .customFont(.regular, Typography.callout)
                .foregroundStyle(.subtitle)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var typeMenu: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Tipe")
            SelectionField(
                options: CompanyType.allCases.map { SelectionOption(id: $0.rawValue, title: $0.label) },
                selectedId: form.type.rawValue,
                placeholder: "Pilih tipe",
                sheetTitle: "Tipe",
                searchPrompt: "Cari tipe…",
                onSelect: { id in
                    if let type = CompanyType(rawValue: id) { form.type = type }
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var parentMenu: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Induk Perusahaan")
            SelectionField(
                options: form.parentOptions.map { SelectionOption(id: $0.id, title: $0.name) },
                selectedId: form.type == .subsidiary && !form.parentId.isEmpty ? form.parentId : nil,
                placeholder: form.type == .holding ? "—" : "Pilih induk",
                sheetTitle: "Induk Perusahaan",
                searchPrompt: "Cari perusahaan…",
                onSelect: { form.parentId = $0 }
            )
            .disabled(form.type == .holding || form.parentOptions.isEmpty)
            .opacity(form.type == .holding ? 0.5 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            Task {
                if await presenter.createCompany() {
                    onSaved()
                    dismiss()
                }
            }
        } label: {
            Group {
                if presenter.isCreatingCompany {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(isEditing ? "Simpan Perubahan" : "Simpan").customFont(.semibold, Typography.body)
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(form.isValid ? Color.accentColor : Color.accentColor.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!form.isValid || presenter.isCreatingCompany)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var bindName: Binding<String> {
        Binding(get: { form.name }, set: { form.name = $0 })
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .customFont(.medium, Typography.body)
            .foregroundStyle(.subtitle)
    }
}
