//
//  StickerDetailViewModel.swift
//  Stekki
//
//  シールのメタデータ編集・完全削除を担当する。
//

import Foundation
import SwiftData

@Observable
final class StickerDetailViewModel {
    let sticker: Sticker
    private let modelContext: ModelContext

    init(sticker: Sticker, modelContext: ModelContext) {
        self.sticker = sticker
        self.modelContext = modelContext
    }

    func updateMetadata(
        authorDisplayName: String,
        wasReceived: Bool,
        receivedFrom: String,
        receivedAt: Date
    ) {
        let trimmedAuthor = authorDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        sticker.authorDisplayName = trimmedAuthor.isEmpty ? "自分" : trimmedAuthor

        if wasReceived {
            let trimmedFrom = receivedFrom.trimmingCharacters(in: .whitespacesAndNewlines)
            sticker.receivedFrom = trimmedFrom.isEmpty ? nil : trimmedFrom
            sticker.receivedAt = receivedAt
        } else {
            sticker.receivedFrom = nil
            sticker.receivedAt = nil
        }
        save()
    }

    /// シール自体を完全に削除する（画像ファイル・履歴も含む）
    func deletePermanently() {
        StickerFileStore.delete(fileName: sticker.imageFileName)
        if let thumbnail = sticker.thumbnailFileName {
            StickerFileStore.delete(fileName: thumbnail)
        }
        modelContext.delete(sticker)
        save()
    }

    private func save() {
        try? modelContext.save()
    }
}
