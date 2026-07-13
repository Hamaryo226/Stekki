//
//  TextStickerSpec.swift
//  Stekki
//
//  テキストシールの元データ（文字・フォント・色・縁取り・形・行揃え・サイズ）。
//  Sticker.textSpecJSON にJSONとして保存しておくことで、シールを作った後・
//  貼った後からでもInstagramストーリーのように文字を再編集できる。
//  色はライト/ダークで変わらないよう "#RRGGBB" のhex文字列で保持する。
//

import UIKit
import SwiftUI

struct TextStickerSpec: Codable, Equatable {
    var text: String
    /// StickerTextFont.rawValue
    var fontID: String
    /// 描画時のフォントサイズ（pt）。大きいほど大きなシールになる。
    var fontSize: Double
    var textColorHex: String
    var hasStroke: Bool
    var strokeColorHex: String
    var strokeWidth: Double
    /// StickerTextStyle.rawValue（文字の形）
    var styleID: String
    var styleIntensity: Double
    var hasPlate: Bool
    var plateColorHex: String
    /// "left" / "center" / "right"
    var alignmentID: String

    /// フォントサイズの許容範囲（エディタの縦スライダーと共通）
    static let fontSizeRange: ClosedRange<Double> = 36...120

    /// 新規作成時の初期値
    static var initial: TextStickerSpec {
        TextStickerSpec(
            text: "",
            fontID: StickerTextFont.rounded.rawValue,
            fontSize: 72,
            textColorHex: "#000000",
            hasStroke: true,
            strokeColorHex: "#FFFFFF",
            strokeWidth: 3,
            styleID: StickerTextStyle.plain.rawValue,
            styleIntensity: 0.5,
            hasPlate: false,
            plateColorHex: "#FFFFFF",
            alignmentID: "center"
        )
    }

    // MARK: - 型付きアクセサ

    var font: StickerTextFont {
        get { StickerTextFont(rawValue: fontID) ?? .rounded }
        set { fontID = newValue.rawValue }
    }

    var style: StickerTextStyle {
        get { StickerTextStyle(rawValue: styleID) ?? .plain }
        set { styleID = newValue.rawValue }
    }

    var textAlignment: NSTextAlignment {
        switch alignmentID {
        case "left": return .left
        case "right": return .right
        default: return .center
        }
    }

    /// 行揃えを左→中央→右の順で循環させる（IGの整列ボタンと同じ挙動）
    mutating func cycleAlignment() {
        switch alignmentID {
        case "left": alignmentID = "center"
        case "center": alignmentID = "right"
        default: alignmentID = "left"
        }
    }

    /// 空白・改行だけではない実質的なテキストがあるか
    var hasRenderableText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - 描画・シリアライズ

    /// この仕様どおりに透明PNGのシール画像を描画する
    func render() -> UIImage? {
        TextStickerRenderer.render(
            text: text,
            font: font,
            textColor: UIColor(Color(hex: textColorHex)),
            strokeColor: UIColor(Color(hex: strokeColorHex)),
            strokeWidth: hasStroke ? CGFloat(strokeWidth) : 0,
            style: style,
            styleIntensity: CGFloat(styleIntensity),
            plateColor: hasPlate ? UIColor(Color(hex: plateColorHex)) : nil,
            fontSize: CGFloat(fontSize),
            alignment: textAlignment
        )
    }

    /// Sticker.textSpecJSON へ保存するためのJSON文字列
    func encodedJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Sticker.textSpecJSON からの復元。壊れたJSONなら nil。
    init?(json: String) {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(TextStickerSpec.self, from: data) else {
            return nil
        }
        self = decoded
    }

    init(
        text: String,
        fontID: String,
        fontSize: Double,
        textColorHex: String,
        hasStroke: Bool,
        strokeColorHex: String,
        strokeWidth: Double,
        styleID: String,
        styleIntensity: Double,
        hasPlate: Bool,
        plateColorHex: String,
        alignmentID: String
    ) {
        self.text = text
        self.fontID = fontID
        self.fontSize = fontSize
        self.textColorHex = textColorHex
        self.hasStroke = hasStroke
        self.strokeColorHex = strokeColorHex
        self.strokeWidth = strokeWidth
        self.styleID = styleID
        self.styleIntensity = styleIntensity
        self.hasPlate = hasPlate
        self.plateColorHex = plateColorHex
        self.alignmentID = alignmentID
    }
}
