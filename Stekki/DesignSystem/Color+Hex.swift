//
//  Color+Hex.swift
//  Stekki
//
//  SwiftDataに保存したhex文字列からColorを復元するための変換ユーティリティ。
//

import SwiftUI

extension Color {
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)

        let r, g, b: Double
        switch sanitized.count {
        case 6:
            r = Double((rgb & 0xFF0000) >> 16) / 255
            g = Double((rgb & 0x00FF00) >> 8) / 255
            b = Double(rgb & 0x0000FF) / 255
        default:
            r = 1; g = 0.85; b = 0.87
        }
        self.init(red: r, green: g, blue: b)
    }

    /// シール帳の表紙・ページ背景に使うプリセットカラーパレット
    static let bookPalette: [String] = [
        "#FFB6C1", // ライトピンク
        "#FFD8A8", // アプリコット
        "#FFF3B0", // レモン
        "#C3F0CA", // ミント
        "#B8E1FF", // スカイブルー
        "#D6C7FF", // ラベンダー
    ]
}
