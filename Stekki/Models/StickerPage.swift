//
//  StickerPage.swift
//  Stekki
//
//  シール帳の1ページ。貼り付けられたシールの位置情報 (StickerPlacement) を保持する。
//

import Foundation
import SwiftData

@Model
final class StickerPage {
    @Attribute(.unique) var id: UUID
    /// ブック内でのページ順序 (0-indexed)
    var pageIndex: Int
    var createdAt: Date

    /// ページ背景のアクセントカラー（Assets の Color Set 名 or hex）
    var backgroundColorHex: String

    var book: StickerBook?

    @Relationship(deleteRule: .cascade, inverse: \StickerPlacement.page)
    var placements: [StickerPlacement] = []

    init(
        id: UUID = UUID(),
        pageIndex: Int,
        backgroundColorHex: String = "#FFFDF7",
        createdAt: Date = .now,
        book: StickerBook? = nil
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.backgroundColorHex = backgroundColorHex
        self.createdAt = createdAt
        self.book = book
    }

    /// zIndex 昇順（背面から前面へ）に並んだ配置一覧
    var sortedPlacements: [StickerPlacement] {
        placements.sorted { $0.zIndex < $1.zIndex }
    }

    /// このページ上で次に使うべき zIndex（常に最前面に追加する用）
    var nextZIndex: Int {
        (placements.map(\.zIndex).max() ?? -1) + 1
    }

    /// ページの表示名（例: "1ページ目"）
    var displayName: String {
        "\(pageIndex + 1)ページ目"
    }
}
