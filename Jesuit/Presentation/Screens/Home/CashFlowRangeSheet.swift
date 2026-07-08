//
//  CashFlowRangeSheet.swift
//  Jesuit
//
//  Custom period picker shared by Home / Laporan / Transfer. Month-grid first
//  (accounting users think in months): a year stepper over 12 month buttons —
//  one tap applies that whole month and dismisses. A collapsible "Rentang
//  harian" section holds a tap-twice range calendar (first tap = start,
//  second = end, span highlighted) for arbitrary day spans.
//

import SwiftUI

struct CashFlowRangeSheet: View {
    let initialRange: (start: Date, end: Date)
    let onApply: (Date, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var year: Int
    @State private var showDayRange: Bool
    @State private var start: Date
    @State private var end: Date

    private let calendar = Calendar.current

    init(initialRange: (start: Date, end: Date), onApply: @escaping (Date, Date) -> Void) {
        self.initialRange = initialRange
        self.onApply = onApply
        _start = State(initialValue: initialRange.start)
        _end = State(initialValue: initialRange.end)
        _year = State(initialValue: Calendar.current.component(.year, from: initialRange.start))
        // Open with the day calendar expanded when the active range is not a
        // whole month — that's what the user is here to adjust.
        _showDayRange = State(initialValue: Self.monthSpan(of: initialRange, calendar: Calendar.current) == nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    yearStepper
                    monthGrid
                    Divider().opacity(0.4)
                    dayRangeSection
                }
                .padding(20)
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Rentang Khusus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }.foregroundStyle(.subtitle)
                }
            }
        }
    }

    // MARK: - Month grid

    /// `id_ID` short month names: Jan, Feb, …, Des.
    private static let monthNames: [String] = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        return f.shortStandaloneMonthSymbols
    }()

    private var yearStepper: some View {
        HStack {
            stepButton(systemImage: "chevron.left") { year -= 1 }
            Spacer()
            Text(String(year))
                .customFont(.semibold, Typography.headline)
                .foregroundStyle(.title)
                .monospacedDigit()
                .contentTransition(.numericText())
            Spacer()
            stepButton(systemImage: "chevron.right") { year += 1 }
        }
        .animation(.snappy, value: year)
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(1...12, id: \.self) { month in
                monthButton(month)
            }
        }
    }

    private func monthButton(_ month: Int) -> some View {
        let selected = isSelectedMonth(month)
        return Button {
            applyMonth(month)
        } label: {
            Text(Self.monthNames[month - 1])
                .customFont(.medium, Typography.subhead)
                .foregroundStyle(selected ? .white : .title)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(selected ? Color.accentColor : Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    /// The active range highlights its month button only when it spans exactly
    /// that whole month (day granularity).
    private func isSelectedMonth(_ month: Int) -> Bool {
        guard let span = Self.monthSpan(of: initialRange, calendar: calendar) else { return false }
        return span.year == year && span.month == month
    }

    /// `(year, month)` when the range covers exactly one whole month, else nil.
    private static func monthSpan(of range: (start: Date, end: Date), calendar cal: Calendar) -> DateComponents? {
        guard let interval = cal.dateInterval(of: .month, for: range.start),
              let lastDay = cal.date(byAdding: .second, value: -1, to: interval.end),
              cal.isDate(range.start, inSameDayAs: interval.start),
              cal.isDate(range.end, inSameDayAs: lastDay) else { return nil }
        return cal.dateComponents([.year, .month], from: interval.start)
    }

    /// Same `[first 00:00, last 23:59:59]` convention as `CashFlowPeriod.dateRange`.
    private func applyMonth(_ month: Int) {
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart)
        else { return }
        onApply(monthStart, monthEnd)
        dismiss()
    }

    // MARK: - Day range (collapsible)

    private var dayRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.snappy) { showDayRange.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("Rentang harian")
                        .customFont(.medium, Typography.body)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(showDayRange ? 180 : 0))
                }
                .foregroundStyle(.accent)
            }

            if showDayRange {
                RangeCalendar(start: $start, end: $end)

                Button {
                    onApply(start, end)
                    dismiss()
                } label: {
                    Text("Terapkan")
                        .customFont(.medium, Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.subtitle)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - RangeCalendar

/// Tap-twice range calendar: Dari/Sampai header cells, a month pager and a
/// 6-week day grid. First tap sets the start (and arms the end), second tap on
/// a later day sets the end; tapping an earlier day restarts the range. The
/// span renders as a soft accent band with filled circles on the endpoints.
/// Writes back `[start 00:00, end 23:59:59]` like `CashFlowPeriod.dateRange`.
private struct RangeCalendar: View {
    @Binding var start: Date
    @Binding var end: Date

    @State private var displayedMonth: Date
    @State private var awaitingEnd = false

    /// Monday-first, matching `CashFlowPeriod`'s week convention.
    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }

    init(start: Binding<Date>, end: Binding<Date>) {
        _start = start
        _end = end
        _displayedMonth = State(initialValue: Calendar.current.startOfDay(for: start.wrappedValue))
    }

    /// Sen … Min (id_ID symbols are Sunday-first; rotate for Monday-first).
    private static let weekdaySymbols: [String] = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        let symbols = f.shortStandaloneWeekdaySymbols ?? []
        return Array(symbols[1...]) + [symbols[0]]
    }()

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private func endpointLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "EEE, dd MMM yyyy"
        return f.string(from: date)
    }

    /// Always 42 cells (6 weeks) from the Monday of the month's first week —
    /// stable grid height across months; adjacent-month days render dimmed.
    private var cells: [Date] {
        guard let monthInterval = cal.dateInterval(of: .month, for: displayedMonth),
              let firstWeek = cal.dateInterval(of: .weekOfYear, for: monthInterval.start)
        else { return [] }
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: firstWeek.start) }
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            pager
            weekdayHeader
            dayGrid
        }
    }

    // MARK: Header (Dari / Sampai)

    private var header: some View {
        HStack(spacing: 0) {
            endpointCell("Dari", date: start, active: !awaitingEnd)
            Divider().frame(height: 32)
            endpointCell("Sampai", date: end, active: awaitingEnd)
        }
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func endpointCell(_ label: String, date: Date, active: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .customFont(.regular, Typography.caption)
                .foregroundStyle(.subtitle)
            Text(endpointLabel(date))
                .customFont(.semibold, Typography.subhead)
                .foregroundStyle(active ? .accent : .title)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Month pager

    private var pager: some View {
        HStack {
            pagerButton("chevron.left", by: -1)
            Spacer()
            Text(monthLabel)
                .customFont(.semibold, Typography.headline)
                .foregroundStyle(.title)
            Spacer()
            pagerButton("chevron.right", by: 1)
        }
        .animation(.snappy, value: displayedMonth)
    }

    private func pagerButton(_ systemImage: String, by months: Int) -> some View {
        Button {
            if let next = cal.date(byAdding: .month, value: months, to: displayedMonth) {
                displayedMonth = next
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.subtitle)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
    }

    // MARK: Day grid

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Self.weekdaySymbols, id: \.self) { day in
                Text(day)
                    .customFont(.medium, Typography.caption)
                    .foregroundStyle(.subtitle)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
            ForEach(cells, id: \.self) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = cal.isDate(day, equalTo: displayedMonth, toGranularity: .month)
        let isStart = cal.isDate(day, inSameDayAs: start)
        let isEnd = cal.isDate(day, inSameDayAs: end)
        let inRange = day >= cal.startOfDay(for: start) && day <= end

        return Button {
            select(day)
        } label: {
            ZStack {
                // Soft band across the span; half-cell insets keep the band
                // starting/ending at the endpoint circles' centers.
                if inRange && !(isStart && isEnd) {
                    RangeBand(isLeadingCap: isStart, isTrailingCap: isEnd)
                }
                if isStart || isEnd {
                    Circle().fill(Color.accentColor)
                }
                Text("\(cal.component(.day, from: day))")
                    .customFont(isStart || isEnd ? .semibold : .regular, Typography.subhead)
                    .monospacedDigit()
                    .foregroundStyle(
                        (isStart || isEnd) ? .white : (inMonth ? .title : Color.subtitle.opacity(0.4))
                    )
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
        }
        .disabled(!inMonth)
    }

    private func select(_ day: Date) {
        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart) ?? dayStart
        if awaitingEnd && dayStart >= cal.startOfDay(for: start) {
            end = dayEnd
            awaitingEnd = false
        } else {
            start = dayStart
            end = dayEnd
            awaitingEnd = true
        }
    }
}

/// The in-range highlight behind a day cell: a flat accent wash, half-width
/// under the endpoint circles so the band visually starts/ends at their centers.
private struct RangeBand: View {
    let isLeadingCap: Bool
    let isTrailingCap: Bool

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.accentColor.opacity(0.22))
                .padding(.leading, isLeadingCap ? geo.size.width / 2 : 0)
                .padding(.trailing, isTrailingCap ? geo.size.width / 2 : 0)
        }
        .padding(.vertical, 4)
    }
}
