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
                    Text(transformSummaryText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
    }

    /// 「x: 50% ・ y: 30% ・ 拡大: 100% ・ 回転: 15°」のような表示文字列。
    /// - Note: この計算を `Text` の文字列補間内に直接書くと、Swiftの型推論が
    ///   複雑になりすぎてビルドが極端に遅くなる／失敗することがあるため、
    ///   明示的な型を持つ独立した計算プロパティに分離している。
    private var transformSummaryText: String {
        let xPercent: Int = Int(entry.x * 100)
        let yPercent: Int = Int(entry.y * 100)
        let scalePercent: Int = Int(entry.scale * 100)
        let rotationDegrees: Int = Int(entry.rotation * 180 / .pi)
        return "x: \(xPercent)% ・ y: \(yPercent)% ・ 拡大: \(scalePercent)% ・ 回転: \(rotationDegrees)°"
    }
}
