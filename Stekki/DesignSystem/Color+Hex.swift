//
//  Color+Hex.swift
//  Stekki
//
//  SwiftDataに保存したhex文字列からColorを復元するための変換ユーティリティ。
//  テキストシールの再編集用に、Color → hex の逆変換も用意する。
//

import SwiftUI
import UIKit

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

    /// "#RRGGBB" 形式のhex文字列（アルファは含めない）。`Color(hex:)` の逆変換。
    var hexRGBString: String {
        UIColor(self).hexRGBString
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

extension UIColor {
    /// "#RRGGBB" 形式のhex文字列（アルファは含めない）。
    /// RGBで取り出せない色空間（グレースケール等）はいったん白黒値から復元する。
    var hexRGBString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if !getRed(&r, green: &g, blue: &b, alpha: &a) {
            var white: CGFloat = 0
            if getWhite(&white, alpha: &a) {
                r = white
                g = white
                b = white
            }
        }
        func component(_ value: CGFloat) -> Int {
            Int((min(max(value, 0), 1) * 255).rounded())
        }
        return String(format: "#%02X%02X%02X", component(r), component(g), component(b))
    }
}
