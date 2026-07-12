//
//  PlacementHistory.swift
//  Stekki
//
//  シールの貼付操作を追記していく履歴ログ（1つの Sticker に対して複数）。
//  StickerPlacement が「現在」の状態であるのに対し、PlacementHistory は「これまでの記録」。
//

import Foundation
import SwiftData

@Model
final class PlacementHistory {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var actionRaw: String

    /// 操作が起きた時点のページ・ブックのスナップショット表示名（ページが削除されても履歴として読めるように文字列で保持）
    var bookTitleSnapshot: String?
    var pageDisplaySnapshot: String?

    /// 操作が起きた時点の座標・拡縮・回転・重なり順
    var x: Double
    var y: Double
    var scale: Double
    var rotation: Double
    var zIndex: Int

    var sticker: Sticker?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        action: PlacementAction,
        bookTitleSnapshot: String?,
        pageDisplaySnapshot: String?,
        x: Double,
        y: Double,
        scale: Double,
        rotation: Double,
        zIndex: Int,
        sticker: Sticker? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actionRaw = action.rawValue
        self.bookTitleSnapshot = bookTitleSnapshot
        self.pageDisplaySnapshot = pageDisplaySnapshot
        self.x = x
        self.y = y
        self.scale = scale
        self.rotation = rotation
        self.zIndex = zIndex
        self.sticker = sticker
    }

    var action: PlacementAction {
        PlacementAction(rawValue: actionRaw) ?? .moved
    }

    /// 履歴一覧に表示する短い説明文
    var summary: String {
        switch action {
        case .placed:
            if let page = pageDisplaySnapshot, let book = bookTitleSnapshot {
                return "「\(book)」\(page) に貼り付け"
            }
            return "貼り付け"
        case .moved:
            return "位置・角度を調整"
        case .movedToPage:
            if let page = pageDisplaySnapshot, let book = bookTitleSnapshot {
                return "「\(book)」\(page) へ移動"
            }
            return "ページを移動"
        case .removedToTray:
            return "トレイに戻した"
        }
    }
}
