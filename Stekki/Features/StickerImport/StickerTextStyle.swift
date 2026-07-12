//
//  StickerTextStyle.swift
//  Stekki
//
//  テキストシールの「文字の形」。まっすぐのほか、アーチ状に曲げたり、
//  波・ふくらみで歪ませたりできる。強さ（intensity）は -1〜+1 で、
//  アーチなら正で上向き・負で下向き、ふくらみなら正で膨張・負でくびれになる。
//

import Foundation

enum StickerTextStyle: String, CaseIterable, Identifiable {
    case plain
    case arch
    case wave
    case bulge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plain: return "なし"
        case .arch: return "アーチ"
        case .wave: return "波"
        case .bulge: return "ふくらみ"
        }
    }

    /// 強さスライダーの下に添える説明
    var intensityHint: String {
        switch self {
        case .plain: return ""
        case .arch: return "左：下向きアーチ ／ 右：上向きアーチ"
        case .wave: return "左右で波の向きが反転します"
        case .bulge: return "左：くびれ ／ 右：ふくらみ"
        }
    }
}
