//
//  StickerTextFont.swift
//  Stekki
//
//  テキストシールで選べるフォントの候補。iOS標準搭載のフォントのみを使用するため
//  追加のフォントファイルは不要。日本語を含む文字列は、選んだフォントに
//  その文字のグリフが無い場合、システムが自動でフォールバックして表示する。
//

import SwiftUI
import UIKit

enum StickerTextFont: String, CaseIterable, Identifiable, Hashable {
    case system
    case rounded
    case handwriting
    case cute
    case typewriter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "標準"
        case .rounded: return "丸ゴシック"
        case .handwriting: return "手書き風"
        case .cute: return "かわいい系"
        case .typewriter: return "タイプライター"
        }
    }

    /// 実際のシール描画（UIGraphicsImageRenderer）に使うフォント
    func uiFont(size: CGFloat) -> UIFont {
        switch self {
        case .system:
            return UIFont.systemFont(ofSize: size, weight: .heavy)
        case .rounded:
            let base = UIFont.systemFont(ofSize: size, weight: .heavy)
            if let descriptor = base.fontDescriptor.withDesign(.rounded) {
                return UIFont(descriptor: descriptor, size: size)
            }
            return base
        case .handwriting:
            return UIFont(name: "MarkerFelt-Wide", size: size) ?? UIFont.systemFont(ofSize: size, weight: .bold)
        case .cute:
            return UIFont(name: "ChalkboardSE-Bold", size: size) ?? UIFont.systemFont(ofSize: size, weight: .bold)
        case .typewriter:
            return UIFont(name: "AmericanTypewriter-Bold", size: size) ?? UIFont.systemFont(ofSize: size, weight: .bold)
        }
    }

    /// フォント選択メニューでのプレビュー表示用（SwiftUI Font）
    var previewFont: Font {
        switch self {
        case .system: return .system(size: 17, weight: .heavy)
        case .rounded: return .system(size: 17, weight: .heavy, design: .rounded)
        case .handwriting: return .custom("MarkerFelt-Wide", size: 18)
        case .cute: return .custom("ChalkboardSE-Bold", size: 17)
        case .typewriter: return .custom("AmericanTypewriter-Bold", size: 16)
        }
    }
}
