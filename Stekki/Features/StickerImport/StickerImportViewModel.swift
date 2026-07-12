//
//  StickerImportViewModel.swift
//  Stekki
//
//  写真の選択 → 背景除去 → 角丸加工 → 透明PNG保存 → Sticker作成、という一連の流れを管理する。
//  すべてオンデバイスで完結し、サーバーへは一切送信しない。
//

import Foundation
import UIKit
import SwiftUI
import PhotosUI
import SwiftData

@Observable
final class StickerImportViewModel {
    private let modelContext: ModelContext

    var processedImage: UIImage?
    var isProcessing = false
    var errorMessage: String?

    /// 背景除去（あり/なし）を反映した、角丸加工前の画像データ。
    /// スライダー操作のたびにVisionを再実行しないよう、これをキャッシュしておく。
    private var baseImageData: Data?
    /// 実際に保存される画像データ（角丸加工後）
    private var pngData: Data?
    private var thumbnailData: Data?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// PhotosPicker で選ばれた写真を読み込み、プレビューを作る。
    /// - Parameters:
    ///   - removeBackground: true の場合はVisionで被写体を切り抜いて透明PNGにする。
    ///     false の場合は背景を残したまま（不透明）シールにする。
    ///   - cornerRadiusFraction: 0.0〜0.5。角を丸くする度合い。
    func process(_ item: PhotosPickerItem, removeBackground: Bool, cornerRadiusFraction: Double) async {
        isProcessing = true
        errorMessage = nil
        processedImage = nil
        baseImageData = nil
        pngData = nil
        thumbnailData = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                throw BackgroundRemoverError.invalidImage
            }

            let resultData: Data
            if removeBackground {
                resultData = try await BackgroundRemover.makeTransparentSticker(from: uiImage)
            } else {
                resultData = try BackgroundRemover.makeOpaqueSticker(from: uiImage)
            }

            baseImageData = resultData
            applyCornerRadius(cornerRadiusFraction)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "処理に失敗しました。もう一度お試しください。"
        }
        isProcessing = false
    }

    /// スライダー操作時など、Visionを再実行せず角丸だけを軽量に再適用する
    func updateCornerRadius(_ fraction: Double) {
        applyCornerRadius(fraction)
    }

    private func applyCornerRadius(_ fraction: Double) {
        guard let baseImageData else { return }
        let rounded = BackgroundRemover.applyCornerRadius(CGFloat(fraction), to: baseImageData) ?? baseImageData
        pngData = rounded
        thumbnailData = BackgroundRemover.makeThumbnail(from: rounded)
        processedImage = UIImage(data: rounded)
    }

    var canSave: Bool { pngData != nil }

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
        reset()
        return sticker
    }

    func reset() {
        processedImage = nil
        baseImageData = nil
        pngData = nil
        thumbnailData = nil
        errorMessage = nil
    }
}
