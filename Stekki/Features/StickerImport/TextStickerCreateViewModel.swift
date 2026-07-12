//
//  TextStickerCreateViewModel.swift
//  Stekki
//
//  テキストシール（文字だけのシール）の作成を担当する。
//  写真からのシール作成 (StickerImportViewModel) と同様、端末内で完結する。
//

import Foundation
import UIKit
import SwiftUI
import SwiftData

@Observable
final class TextStickerCreateViewModel {
    private let modelContext: ModelContext

    var previewImage: UIImage?
    var errorMessage: String?

    private var pngData: Data?
    private var thumbnailData: Data?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var canSave: Bool { pngData != nil }

    /// テキスト・フォント・色・縁取り・文字の形などが変わるたびに呼び、プレビューを再描画する
    func updatePreview(
        text: String,
        font: StickerTextFont,
        textColor: Color,
        strokeColor: Color,
        strokeWidth: Double,
        style: StickerTextStyle = .plain,
        styleIntensity: Double = 0,
        plateColor: Color? = nil
    ) {
        guard let image = TextStickerRenderer.render(
            text: text,
            font: font,
            textColor: UIColor(textColor),
            strokeColor: UIColor(strokeColor),
            strokeWidth: CGFloat(strokeWidth),
            style: style,
            styleIntensity: CGFloat(styleIntensity),
            plateColor: plateColor.map { UIColor($0) }
        ) else {
            previewImage = nil
            pngData = nil
            thumbnailData = nil
            return
        }

        previewImage = image
        let data = image.pngData()
        pngData = data
        thumbnailData = data.flatMap { BackgroundRemover.makeThumbnail(from: $0) }
    }

    /// 端末内へ保存し、未貼付トレイに入る Sticker を作成する
    @discardableResult
    func saveSticker(
        authorDisplayName: String,
        wasReceived: Bool,
        receivedFrom: String,
        receivedAt: Date
    ) -> Sticker? {
        guard let pngData else { return nil }
        guard let fileName = try? StickerFileStore.save(pngData: pngData) else {
            errorMessage = "画像の保存に失敗しました。"
            return nil
        }
        let thumbFileName = thumbnailData.flatMap { try? StickerFileStore.save(pngData: $0) }

        let trimmedAuthor = authorDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFrom = receivedFrom.trimmingCharacters(in: .whitespacesAndNewlines)

        let sticker = Sticker(
            imageFileName: fileName,
            thumbnailFileName: thumbFileName,
            authorDisplayName: trimmedAuthor.isEmpty ? "自分" : trimmedAuthor,
            receivedAt: wasReceived ? receivedAt : nil,
            receivedFrom: wasReceived && !trimmedFrom.isEmpty ? trimmedFrom : nil
        )
        modelContext.insert(sticker)
        try? modelContext.save()
        return sticker
    }
}
