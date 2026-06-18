//
//  KPICard.swift
//  Jesuit
//
//  Single KPI metric tile.
//

import SwiftUI

struct KPICard: View {
    let kpi: KPI

    private var isUp: Bool { kpi.deltaPercent >= 0 }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: kpi.systemImage)
                        .font(.system(size: 18))
                        .foregroundStyle(.accent)
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                        Text(String(format: "%.1f%%", abs(kpi.deltaPercent)))
                    }
                    .font(.customFont(.semibold, Typography.caption))
                    .foregroundStyle(isUp ? Color.income : Color.expense)
                }

                Text(kpi.amount.asCompactCurrency)
                    .customFont(.bold, Typography.title)
                    .foregroundStyle(.title)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(LocalizedStringKey(kpi.title))
                    .customFont(.regular, Typography.subhead)
                    .foregroundStyle(.subtitle)
                    .lineLimit(1)
            }
        }
    }
}
