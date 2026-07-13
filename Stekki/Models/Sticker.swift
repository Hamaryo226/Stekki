//
//  Sticker.swift
//  Stekki
//
//  1枚のシール本体。写真から作成した透明PNGを端末内に保存し、そのファイル名を保持する。
//

import Foundation
import SwiftData

@Model
final class Sticker {
    @Attribute(.unique) var id: UUID

    /// StickerFileStore の管理ディレクトリ内でのファイル名（本体画像・透明PNG）
    var imageFileName: String
    /// 同上、サムネイル用（省略時は本体を縮小表示）
    var thumbnailFileName: String?

    /// シール（画像）を端末に取り込んだ日時
    var createdAt: Date
    /// 作成者の表示名（アカウント無しのため自由入力のニックネーム）
    var authorDisplayName: String

    /// 交換で受け取った場合の受取日時（自分で作成した場合は nil）
    var receivedAt: Date?
    /// 受取元（相手のニックネームや場所など、自由入力）
    var receivedFrom: String?

    /// トレイから非表示にする（削除はしないがUI上隠す）場合に使用
    var isArchived: Bool

    /// テキストシールの場合、元の文字・フォント・色などの仕様（TextStickerSpec のJSON）。
    /// これを保持しておくことで、作った後・貼った後からでも文字を再編集できる。
    /// 写真から作ったシールでは nil。
    var textSpecJSON: String? = nil

    /// 現在の貼付状態。nil の場合は未貼付トレイにある。
    @Relationship(deleteRule: .cascade, inverse: \StickerPlacement.sticker)
    var placement: StickerPlacement?

    /// これまでの貼付履歴（新しい順に表示することが多い）
    @Relationship(deleteRule: .cascade, inverse: \PlacementHistory.sticker)
    var history: [PlacementHistory] = []

    init(
        id: UUID = UUID(),
        imageFileName: String,
        thumbnailFileName: String? = nil,
        createdAt: Date = .now,
        authorDisplayName: String,
        receivedAt: Date? = nil,
        receivedFrom: String? = nil,
        isArchived: Bool = false,
        textSpecJSON: String? = nil
    ) {
        self.id = id
        self.imageFileName = imageFileName
        self.thumbnailFileName = thumbnailFileName
        self.createdAt = createdAt
        self.authorDisplayName = authorDisplayName
        self.receivedAt = receivedAt
        self.receivedFrom = receivedFrom
        self.isArchived = isArchived
        self.textSpecJSON = textSpecJSON
    }

    /// 現在貼られているか（トレイにあるかどうかの逆）
    var isPlaced: Bool { placement != nil }

    /// 文字から作ったシールか（再編集できるのはこの場合のみ）
    var isTextSticker: Bool { textSpecJSON != nil }

    /// 履歴を新しい順に並べたもの
    var sortedHistory: [PlacementHistory] {
        history.sorted { $0.timestamp > $1.timestamp }
    }

    /// 自分で作成したものか、交換で受け取ったものか
    var isSelfMade: Bool { receivedAt == nil && receivedFrom == nil }
}
