//
//  ProjectSummaryCard.swift
//  Jesuit
//
//  Dashboard "Project Summary": a project timer (Log Time / Start Timer) plus
//  unbilled-hours and unbilled-expenses rows.
//

import SwiftUI

struct ProjectSummaryCard: View {
    let timerDisplay: String
    let isRunning: Bool
    let unbilledHours: String
    let unbilledExpenses: Double

    var onToggleTimer: () -> Void
    var onLogTime: () -> Void

    private let cardRadius: CGFloat = 18

    var body: some View {
        VStack(spacing: 16) {
            timerCard
            unbilledRow(
                title: "Unbilled Hours",
                value: {
                    (Text(unbilledHours).foregroundStyle(.title)
                        + Text(" Hrs").foregroundStyle(.subtitle))
                        .customFont(.bold, 18)
                }
            )
            unbilledRow(
                title: "Unbilled Expenses",
                value: {
                    Text(unbilledExpenses.asIDR)
                        .foregroundStyle(.title)
                        .customFont(.bold, 18)
                }
            )
        }
    }

    // MARK: - Timer card

    private var timerCard: some View {
        VStack(spacing: 18) {
            Text(timerDisplay)
                .customFont(.bold, 44)
                .foregroundStyle(.white)
                .monospacedDigit()

            Text("Start Project Timer")
                .customFont(.medium, 22)
                .foregroundStyle(Color.white.opacity(0.9))

            HStack(spacing: 14) {
                Button(action: onLogTime) {
                    Text("Log Time")
                        .customFont(.semibold, 18)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(Color(red: 0.06, green: 0.07, blue: 0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button(action: onToggleTimer) {
                    HStack(spacing: 10) {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(isRunning ? "Stop Timer" : "Start Timer")
                            .customFont(.semibold, 18)
                    }
                    .foregroundStyle(Color(red: 0.06, green: 0.07, blue: 0.25))
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 0.16, green: 0.27, blue: 0.45),
                         Color(red: 0.13, green: 0.22, blue: 0.40)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
    }

    // MARK: - Unbilled rows

    private func unbilledRow<V: View>(
        title: String,
        @ViewBuilder value: () -> V
    ) -> some View {
        HStack {
            Text(title)
                .customFont(.regular, 18)
                .foregroundStyle(.subtitle)
            Spacer()
            value()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.subtitle)
        }
        .padding(.horizontal, 18)
        .frame(height: 64)
        .background(Color(red: 0.06, green: 0.07, blue: 0.18).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
