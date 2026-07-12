//
//  BookListViewModel.swift
//  Stekki
//
//  シール帳一覧の作成・削除ロジック。
//

import Foundation
import SwiftData
import SwiftUI

@Observable
final class BookListViewModel {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// 新しいシール帳を1ページ目付きで作成する
    @discardableResult
    func createBook(title: String) -> StickerBook {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let book = StickerBook(
            title: trimmed.isEmpty ? "新しいシール帳" : trimmed,
            coverColorHex: Color.bookPalette.randomElement() ?? "#FFB6C1"
        )
        let firstPage = StickerPage(pageIndex: 0, book: book)
        book.pages.append(firstPage)
        modelContext.insert(book)
        save()
        return book
    }

    func delete(_ book: StickerBook) {
        modelContext.delete(book)
        save()
    }

    func rename(_ book: StickerBook, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        book.title = trimmed
        book.updatedAt = .now
        save()
    }

    private func save() {
        try? modelContext.save()
    }
}
