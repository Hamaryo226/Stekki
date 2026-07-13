//
//  StickerPlacement.swift
//  Stekki
//
//  シールの「現在の」貼付状態。1つの Sticker が貼られていれば必ず1つだけ存在する（1:1）。
//  トレイ（未貼付）の状態は Sticker.placement が nil であることで表現する。
//

import Foundation
import SwiftData

@Model
final class StickerPlacement {
    @Attribute(.unique) var id: UUID

    /// 正規化X座標 (0.0〜1.0, ページ左端=0, 右端=1)
    var x: Double
    /// 正規化Y座標 (0.0〜1.0, ページ上端=0, 下端=1)
    var y: Double
    /// 拡大率 (1.0 = 基準サイズ)
    var scale: Double
    /// 回転角（ラジアン）
    var rotation: Double
    /// 重なり順（大きいほど前面）
    var zIndex: Int
    /// 左右反転しているか
    var isFlippedHorizontally: Bool = false
    /// 影を表示するか（貼ってあるだけでなく「浮いている」ような見た目にする）
    var hasShadow: Bool = false
    /// 貼付後にかけるエフェクト（StickerEffect.rawValue を保存する）
    var effectRawValue: String = "none"
    /// この位置に貼られた／最後に更新された日時
    var placedAt: Date

    var sticker: Sticker?
    var page: StickerPage?

    init(
        id: UUID = UUID(),
        x: Double,
        y: Double,
        scale: Double = 1.0,
        rotation: Double = 0.0,
        zIndex: Int = 0,
        isFlippedHorizontally: Bool = false,
        hasShadow: Bool = false,
        effect: StickerEffect = .none,
        placedAt: Date = .now,
        sticker: Sticker? = nil,
        page: StickerPage? = nil
    ) {
        self.id = id
        self.x = x.clamped(to: 0...1)
        self.y = y.clamped(to: 0...1)
        self.scale = scale
        self.rotation = rotation
        self.zIndex = zIndex
        self.isFlippedHorizontally = isFlippedHorizontally
        self.hasShadow = hasShadow
        self.effectRawValue = effect.rawValue
        self.placedAt = placedAt
        self.sticker = sticker
        self.page = page
    }
}

extension StickerPlacement {
    /// 保存されているエフェクト。未知の値（将来のバージョンで追加された値など）は「なし」として扱う。
    var effect: StickerEffect {
        get { StickerEffect(rawValue: effectRawValue) ?? StickerEffect.none }
        set { effectRawValue = newValue.rawValue }
    }

    /// 拡大率の許容範囲。ジェスチャ中のラバーバンドと確定時のクランプの両方で共通に使う
    /// （ビューとViewModelで別々の値を持って食い違わないよう、ここに1箇所で定義する）。
    static let scaleRange: ClosedRange<Double> = 0.25...4.0
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
