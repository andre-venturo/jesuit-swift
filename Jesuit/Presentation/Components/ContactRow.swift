//
//  ContactRow.swift
//  Jesuit
//
//  Single contact list row: avatar, name, and a secondary detail line built
//  from fields the API actually returns (company / email / phone).
//

import SwiftUI

struct ContactRow: View {
    let contact: Contact

    /// First non-empty real field from the API for the subtitle line.
    private var subtitle: String? {
        [contact.company, contact.email, contact.phone]
            .compactMap { $0 }
            .first { !$0.isEmpty }
    }

    var body: some View {
        HStack(alignment: .center, spacing: ListMetrics.horizontalInset) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 52, height: 52)
                .overlay(
                    Text(contact.initials)
                        .customFont(.semibold, ListMetrics.titleSize)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .customFont(.bold, ListMetrics.titleSize)
                    .foregroundStyle(.title)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .customFont(.regular, ListMetrics.metaSize)
                        .foregroundStyle(.subtitle)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(contact.kind.rawValue)
                .customFont(.medium, ListMetrics.statusSize)
                .foregroundStyle(.subtitle)
        }
        .padding(.vertical, ListMetrics.rowVerticalPadding)
    }
}
