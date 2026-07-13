//
//  TextStickerEditorViewModel.swift
//  Stekki
//
//  テキストシールの新規作成と、既存テキストシールの再編集（画像の差し替え）を担当する。
//  写真からのシール作成 (StickerImportViewModel) と同様、端末内で完結する。
//

import Foundation
import UIKit
import SwiftData

@Observable
final class TextStickerEditorViewModel {
    private let modelContext: ModelContext

    var errorMessage: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// 仕様どおりに描画して端末内へ保存し、未貼付トレイに入る新しい Sticker を作成する。
    /// 再編集できるよう、元の文字仕様（JSON）も一緒に保存する。
    @discardableResult
    func saveNew(spec: TextStickerSpec) -> Sticker? {
        guard let files = renderAndStore(spec: spec) else { return nil }
        let sticker = Sticker(
            imageFileName: files.imageFileName,
            thumbnailFileName: files.thumbnailFileName,
            authorDisplayName: "自分",
            textSpecJSON: spec.encodedJSON()
        )
        modelContext.insert(sticker)
        try? modelContext.save()
        return sticker
    }

    /// 既存のテキストシールを新しい仕様で描画し直し、画像を差し替える。
    /// 貼付状態・履歴・作成日時などはそのまま維持される（同じシールの文字だけ変わる）。
    @discardableResult
    func update(sticker: Sticker, spec: TextStickerSpec) -> Bool {
        guard let files = renderAndStore(spec: spec) else { return false }

        let oldImage = sticker.imageFileName
        let oldThumbnail = sticker.thumbnailFileName
        sticker.imageFileName = files.imageFileName
        sticker.thumbnailFileName = files.thumbnailFileName
        sticker.textSpecJSON = spec.encodedJSON()
        try? modelContext.save()

        // 古い画像ファイルと、それを元に生成したキャッシュを片付ける
        for fileName in [oldImage, oldThumbnail].compactMap({ $0 }) {
            StickerFileStore.delete(fileName: fileName)
            StickerImageCache.shared.invalidate(fileName: fileName)
            StickerEffectRenderer.invalidate(fileName: fileName)
        }
        return true
    }

    /// 描画 → PNG化 → ファイル保存までを行い、保存したファイル名を返す
    private func renderAndStore(spec: TextStickerSpec) -> (imageFileName: String, thumbnailFileName: String?)? {
        guard let image = spec.render(), let pngData = image.pngData() else {
            errorMessage = "シール画像の生成に失敗しました。"
            return nil
        }
        guard let fileName = try? StickerFileStore.save(pngData: pngData) else {
            errorMessage = "画像の保存に失敗しました。"
            return nil
        }
        let thumbnailFileName = BackgroundRemover.makeThumbnail(from: pngData)
            .flatMap { try? StickerFileStore.save(pngData: $0) }
        return (fileName, thumbnailFileName)
    }
}
