//
//  StickerEffect.swift
//  Stekki
//
//  貼ったシールにかけられるエフェクト。Instagramストーリーのステッカーを
//  タップすると見た目が切り替わるのと同じように、ツールバーのボタンを
//  タップするたびに「なし → 白フチ → キラキラ → なし…」と循環する。
//

import Foundation

enum StickerEffect: String, CaseIterable, Identifiable {
    /// エフェクトなし（元の画像のまま）
    case none
    /// IGのステッカーのような、被写体の形に沿った白い縁取り
    case whiteOutline
    /// 光っているようなグロー（キラキラ）
    case glow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "エフェクトなし"
        case .whiteOutline: return "白フチ"
        case .glow: return "キラキラ"
        }
    }

    /// ミニツールバーのボタンに表示するアイコン
    var iconName: String {
        switch self {
        case .none: return "wand.and.rays.inverse"
        case .whiteOutline: return "seal.fill"
        case .glow: return "sparkles"
        }
    }

    /// タップで循環する次のエフェクト
    var next: StickerEffect {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }
}
