//
//  SummaryBanner.swift
//  Jesuit
//
//  Headline total banner for receipt / expense screens.
//

import SwiftUI

struct SummaryBanner: View {
    let title: LocalizedStringKey
    let amount: Double
    let systemImage: String
    let tint: Color

    var body: some View {
        CardContainer(padding: 20) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 28))
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .customFont(.regular, Typography.callout)
                        .foregroundStyle(.subtitle)
                    Text(amount.asCurrency)
                        .customFont(.bold, Typography.largeTitle)
                        .foregroundStyle(.title)
                }
                Spacer()
            }
        }
    }
}
