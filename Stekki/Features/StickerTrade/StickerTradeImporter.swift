//
//  StickerTradeImporter.swift
//  Stekki
//
//  受信した .stickertrade を「信頼できない入力」として検証しながら読み込む。
//
//  検証の順序:
//  1. ZIP展開前（セントラルディレクトリの宣言値のみで判断）
//     - アーカイブ全体の容量上限
//     - エントリ数がちょうど4であること
//     - エントリ名が manifest.json / sticker.png / thumbnail.png / integrity.json に一致すること（拡張子含む）
//     - 各エントリの宣言サイズ（圧縮前後）が上限内であること
//  2. ZIP展開後
//     - 実際の展開サイズ・CRC32が宣言と一致すること（ZipArchiveReader内）
//     - integrity.json に記録された SHA-256 と一致すること
//     - manifest.json のフォーマットバージョンが対応範囲であること
//     - PNGシグネチャを持ち、デコードでき、ピクセルサイズが上限内であること
//
//  ここでは検証と読み込みのみを行い、保存はしない。保存は受け取り画面で
//  利用者が「トレイに追加」を押したときにだけ行う。
//

import Foundation
import UIKit

enum StickerTradeImportError: Error, LocalizedError {
    case archiveTooLarge
    case invalidArchive(String)
    case wrongEntries
    case entryTooLarge(String)
    case invalidIntegrityFile
    case integrityMismatch(String)
    case invalidManifest
    case unsupportedVersion(Int)
    case notPNG(String)
    case undecodableImage(String)
    case imageTooLarge(String)

    var errorDescription: String? {
        switch self {
        case .archiveTooLarge:
            return "ファイルが大きすぎます。"
        case .invalidArchive(let detail):
            return "シール交換ファイルとして読み込めませんでした（\(detail)）。"
        case .wrongEntries:
            return "シール交換ファイルの中身が想定と異なります。"
        case .entryTooLarge(let name):
            return "ファイル内の \(name) が大きすぎます。"
        case .invalidIntegrityFile:
            return "整合性情報（integrity.json）を読み取れませんでした。"
        case .integrityMismatch(let name):
            return "\(name) のSHA-256が一致しません。転送中に壊れたか、改ざんされた可能性があります。"
        case .invalidManifest:
            return "シール情報（manifest.json）を読み取れませんでした。"
        case .unsupportedVersion(let version):
            return "このファイルは新しいバージョンのStekki（フォーマットv\(version)）で作られています。アプリを更新してください。"
        case .notPNG(let name):
            return "\(name) がPNG画像ではありません。"
        case .undecodableImage(let name):
            return "\(name) を画像として読み込めませんでした。"
        case .imageTooLarge(let name):
            return "\(name) の画像サイズが大きすぎます。"
        }
    }
}

/// 検証済みの受信内容。プレビュー表示と「トレイに追加」で使う。
struct StickerTradePayload: Identifiable {
    let id = UUID()
    let manifest: StickerTradeManifest
    let stickerPNGData: Data
    let thumbnailPNGData: Data
    let stickerImage: UIImage
}

enum StickerTradeImporter {

    /// .stickertrade のバイト列を検証し、プレビュー用ペイロードを返す（保存はしない）
    static func importArchive(_ archiveData: Data) throws -> StickerTradePayload {
        // --- 展開前の検証 ---
        guard archiveData.count <= StickerTradeFormat.maxArchiveBytes else {
            throw StickerTradeImportError.archiveTooLarge
        }

        let reader: ZipArchiveReader
        do {
            reader = try ZipArchiveReader(data: archiveData)
        } catch {
            throw StickerTradeImportError.invalidArchive(
                (error as? LocalizedError)?.errorDescription ?? "ZIPの解析に失敗"
            )
        }

        // ファイル数と名前（=拡張子も）が想定の4つちょうどであること
        let entryNames = reader.entries.map(\.name)
        guard entryNames.count == 4,
              Set(entryNames) == StickerTradeFormat.requiredEntryNames else {
            throw StickerTradeImportError.wrongEntries
        }
        for entry in reader.entries {
            let ext = (entry.name as NSString).pathExtension.lowercased()
            guard StickerTradeFormat.allowedEntryExtensions.contains(ext) else {
                throw StickerTradeImportError.wrongEntries
            }
            let cap = StickerTradeFormat.maxBytes(forEntryName: entry.name)
            guard entry.uncompressedSize <= cap, entry.compressedSize <= cap else {
                throw StickerTradeImportError.entryTooLarge(entry.name)
            }
        }

        // --- 展開（サイズ・CRC32はリーダー内で照合される） ---
        var extracted: [String: Data] = [:]
        for entry in reader.entries {
            do {
                extracted[entry.name] = try reader.extractData(of: entry)
            } catch {
                throw StickerTradeImportError.invalidArchive(
                    (error as? LocalizedError)?.errorDescription ?? "展開に失敗"
                )
            }
        }
        guard let manifestData = extracted[StickerTradeFormat.manifestEntryName],
              let stickerPNGData = extracted[StickerTradeFormat.stickerEntryName],
              let thumbnailPNGData = extracted[StickerTradeFormat.thumbnailEntryName],
              let integrityData = extracted[StickerTradeFormat.integrityEntryName] else {
            throw StickerTradeImportError.wrongEntries
        }

        // --- SHA-256 の照合 ---
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let integrity = try? decoder.decode(StickerTradeIntegrity.self, from: integrityData),
              integrity.algorithm == StickerTradeFormat.integrityAlgorithm,
              Set(integrity.files.keys) == [
                  StickerTradeFormat.manifestEntryName,
                  StickerTradeFormat.stickerEntryName,
                  StickerTradeFormat.thumbnailEntryName,
              ] else {
            throw StickerTradeImportError.invalidIntegrityFile
        }
        let hashTargets: [(name: String, data: Data)] = [
            (StickerTradeFormat.manifestEntryName, manifestData),
            (StickerTradeFormat.stickerEntryName, stickerPNGData),
            (StickerTradeFormat.thumbnailEntryName, thumbnailPNGData),
        ]
        for (name, data) in hashTargets {
            guard integrity.files[name]?.lowercased() == StickerTradeFormat.sha256Hex(data) else {
                throw StickerTradeImportError.integrityMismatch(name)
            }
        }

        // --- manifest の検証 ---
        guard let manifest = try? decoder.decode(StickerTradeManifest.self, from: manifestData) else {
            throw StickerTradeImportError.invalidManifest
        }
        guard manifest.formatVersion <= StickerTradeFormat.formatVersion else {
            throw StickerTradeImportError.unsupportedVersion(manifest.formatVersion)
        }

        // --- 画像の検証 ---
        let stickerImage = try validatePNG(
            stickerPNGData,
            name: StickerTradeFormat.stickerEntryName,
            maxPixelDimension: StickerTradeFormat.maxStickerPixelDimension
        )
        _ = try validatePNG(
            thumbnailPNGData,
            name: StickerTradeFormat.thumbnailEntryName,
            maxPixelDimension: StickerTradeFormat.maxThumbnailPixelDimension
        )

        return StickerTradePayload(
            manifest: manifest,
            stickerPNGData: stickerPNGData,
            thumbnailPNGData: thumbnailPNGData,
            stickerImage: stickerImage
        )
    }

    /// PNGシグネチャ・デコード可否・ピクセルサイズを検証し、デコード済み画像を返す
    @discardableResult
    private static func validatePNG(
        _ data: Data, name: String, maxPixelDimension: Int
    ) throws -> UIImage {
        let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard data.count > pngSignature.count,
              data.prefix(pngSignature.count).elementsEqual(pngSignature) else {
            throw StickerTradeImportError.notPNG(name)
        }
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            throw StickerTradeImportError.undecodableImage(name)
        }
        guard cgImage.width >= 1, cgImage.height >= 1,
              cgImage.width <= maxPixelDimension, cgImage.height <= maxPixelDimension else {
            throw StickerTradeImportError.imageTooLarge(name)
        }
        return image
    }
}
