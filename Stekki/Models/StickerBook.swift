//
//  StickerBook.swift
//  Stekki
//
//  デジタルシール帳そのもの。複数の StickerPage を持つ。
//

import Foundation
import SwiftData

@Model
final class StickerBook {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    /// 表紙のアクセントカラー（Assets の Color Set 名 or hex）
    var coverColorHex: String

    @Relationship(deleteRule: .cascade, inverse: \StickerPage.book)
    var pages: [StickerPage] = []

    init(
        id: UUID = UUID(),
        title: String,
        coverColorHex: String = "#FFB6C1",
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.coverColorHex = coverColorHex
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// ページ番号順に並んだページ一覧
    var sortedPages: [StickerPage] {
        pages.sorted { $0.pageIndex < $1.pageIndex }
    }

    /// 全ページに貼られているシールの総数
    var totalPlacedStickerCount: Int {
        pages.reduce(0) { $0 + $1.placements.count }
    }
}
