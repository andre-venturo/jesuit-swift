//
//  ReportComponents.swift
//  Jesuit
//
//  Shared UI for the report screens: the capsule chip (same style as the
//  list tabs' filter chips), the period-menu chip driven by ReportPeriod,
//  the centered company/report header and the centered state message.
//

import SwiftUI

/// Capsule chip in the list tabs' style; `active` fills it accent.
struct ReportChip: View {
    let icon: String
    let text: String
    var active = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
            Text(text)
                .customFont(.medium, Typography.subhead)
                .lineLimit(1)
        }
        .foregroundStyle(active ? .white : .title)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(active ? Color.accentColor : Color.white.opacity(0.06))
        .clipShape(Capsule())
    }
}

/// Calendar chip whose Menu picks a preset period or opens the custom-range
/// sheet (the checkmark moves to "Rentang Khusus…" while a range is active).
struct PeriodMenuChip: View {
    @Bindable var period: ReportPeriod
    @Binding var showCustomRange: Bool

    var body: some View {
        Menu {
            Picker("Periode", selection: Binding<CashFlowPeriod?>(
                get: { period.hasCustomRange ? nil : period.cashFlowPeriod },
                set: { if let value = $0 { period.cashFlowPeriod = value } }
            )) {
                ForEach(CashFlowPeriod.allCases) { preset in
                    Text(preset.rawValue).tag(Optional(preset))
                }
            }
            .menuOrder(.fixed)
            Divider()
            Button {
                showCustomRange = true
            } label: {
                Label("Rentang Khusus…", systemImage: period.hasCustomRange ? "checkmark" : "calendar")
            }
        } label: {
            ReportChip(icon: "calendar", text: period.label)
        }
        .animation(.snappy, value: period.label)
    }
}

/// Centered company + report title + period line (LaporanScreen's header style).
struct ReportHeader: View {
    let organization: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Text(organization)
                .customFont(.regular, ListMetrics.metaSize)
                .foregroundStyle(.subtitle)
            Text(title)
                .customFont(.semibold, Typography.title2)
                .foregroundStyle(.title)
            Text(subtitle)
                .customFont(.regular, ListMetrics.metaSize)
                .foregroundStyle(.subtitle)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

/// Empty/error message centered in the visible scroll area (75% height ≈
/// optical center once the chip row above is accounted for).
struct ReportStateMessage: View {
    let text: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.subtitle)
            Text(text)
                .customFont(.medium, Typography.body)
                .foregroundStyle(.subtitle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical) { length, _ in length * 0.75 }
    }
}

/// "18 Jun 2026 — 25 Jul 2026" for a report header subtitle.
func reportRangeText(_ range: (start: Date, end: Date)) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "id_ID")
    f.dateFormat = "dd MMM yyyy"
    return "\(f.string(from: range.start)) — \(f.string(from: range.end))"
}
