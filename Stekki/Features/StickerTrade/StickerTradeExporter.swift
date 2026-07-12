//
//  StickerTradeExporter.swift
//  Stekki
//
//  Sticker 1枚を .stickertrade ファイル（ZIP: manifest.json / sticker.png / thumbnail.png / integrity.json）
//  に書き出す。書き出し先は一時ディレクトリで、UIActivityViewController（AirDrop等）に渡して共有する。
//

import Foundation
import UIKit

enum StickerTradeExportError: Error, LocalizedError {
    case imageMissing
    case thumbnailFailed
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .imageMissing:
            return "シールの画像ファイルが見つかりませんでした。"
        case .thumbnailFailed:
            return "サムネイルの生成に失敗しました。"
        case .writeFailed(let error):
            return "送信用ファイルの書き出しに失敗しました: \(error.localizedDescription)"
        }
    }
}

enum StickerTradeExporter {

    /// シールを .stickertrade ファイルとして一時ディレクトリへ書き出し、そのURLを返す。
    /// 共有シートを閉じたら呼び出し側で削除してよい（残っていてもシステムがtmpを掃除する）。
    static func exportFile(for sticker: Sticker) throws -> URL {
        guard let stickerPNGData = try? Data(contentsOf: StickerFileStore.url(for: sticker.imageFileName)) else {
            throw StickerTradeExportError.imageMissing
        }

        // サムネイルは保存済みのものを使い、なければ本体から生成する
        let thumbnailPNGData: Data
        if let thumbnailFileName = sticker.thumbnailFileName,
           let saved = try? Data(contentsOf: StickerFileStore.url(for: thumbnailFileName)) {
            thumbnailPNGData = saved
        } else if let generated = BackgroundRemover.makeThumbnail(from: stickerPNGData) {
            thumbnailPNGData = generated
        } else {
            throw StickerTradeExportError.thumbnailFailed
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601

        let manifest = StickerTradeManifest(
            formatVersion: StickerTradeFormat.formatVersion,
            stickerID: sticker.id,
            authorDisplayName: sticker.authorDisplayName,
            createdAt: sticker.createdAt,
            exportedAt: .now
        )
        let manifestData: Data
        let integrityData: Data
        do {
            manifestData = try encoder.encode(manifest)
            let integrity = StickerTradeIntegrity(
                algorithm: StickerTradeFormat.integrityAlgorithm,
                files: [
                    StickerTradeFormat.manifestEntryName: StickerTradeFormat.sha256Hex(manifestData),
                    StickerTradeFormat.stickerEntryName: StickerTradeFormat.sha256Hex(stickerPNGData),
                    StickerTradeFormat.thumbnailEntryName: StickerTradeFormat.sha256Hex(thumbnailPNGData),
                ]
            )
            integrityData = try encoder.encode(integrity)
        } catch {
            throw StickerTradeExportError.writeFailed(error)
        }

        let archive = ZipArchiveWriter.makeArchive(entries: [
            (StickerTradeFormat.manifestEntryName, manifestData),
            (StickerTradeFormat.stickerEntryName, stickerPNGData),
            (StickerTradeFormat.thumbnailEntryName, thumbnailPNGData),
            (StickerTradeFormat.integrityEntryName, integrityData),
        ])

        let fileName = "Stekki-\(sticker.id.uuidString.prefix(8)).\(StickerTradeFormat.fileExtension)"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try archive.write(to: fileURL, options: .atomic)
        } catch {
            throw StickerTradeExportError.writeFailed(error)
        }
        return fileURL
    }
}
