//
//  PlacementHistoryRow.swift
//  Stekki
//
//  貼付履歴タイムラインの1行。
//

import SwiftUI

struct PlacementHistoryRow: View {
    let entry: PlacementHistory

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.action.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor.gradient))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                    .font(.subheadline.weight(.medium))
                Text(entry.timestamp, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if entry.action == .moved || entry.action == .placed || entry.action == .movedToPage {
                    Text("x: \(Int(entry.x * 100))% ・ y: \(Int(entry.y * 100))% ・ 拡大: \(Int(entry.scale * 100))% ・ 回転: \(Int(entry.rotation * 180 / .pi))°")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
    }
}
