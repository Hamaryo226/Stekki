//
//  StickerTradeFormat.swift
//  Stekki
//
//  AirDrop等で交換する .stickertrade ファイル（実体はZIP）のフォーマット定義。
//  ZIP内には manifest.json / sticker.png / thumbnail.png / integrity.json の4ファイルだけを含める。
//  integrity.json には他3ファイルの SHA-256 を記録し、受信時に改ざん・破損を検出する。
//
//  AirDropは「相手のアプリが受信処理を完了したか」を送信側から確認できないため、
//  このフォーマットは一方向の「送る」「受け取る」のみを表し、原子的な交換（送ったら手元から消える）は扱わない。
//

import Foundation
import CryptoKit
import UniformTypeIdentifiers

extension UTType {
    /// .stickertrade ファイルのUTI。Info.plist の UTExportedTypeDeclarations の定義と一致させること。
    static let stickerTrade = UTType(exportedAs: "jp.hamaryo.stekki.stickertrade", conformingTo: .data)
}

enum StickerTradeFormat {
    /// フォーマットのバージョン。互換性のない変更をしたらインクリメントする。
    static let formatVersion = 1
    static let fileExtension = "stickertrade"

    // ZIP内のエントリ名。受信時はこの4つ「ちょうど」であることを要求する。
    static let manifestEntryName = "manifest.json"
    static let stickerEntryName = "sticker.png"
    static let thumbnailEntryName = "thumbnail.png"
    static let integrityEntryName = "integrity.json"

    static var requiredEntryNames: Set<String> {
        [manifestEntryName, stickerEntryName, thumbnailEntryName, integrityEntryName]
    }

    /// ZIP内で許可する拡張子
    static let allowedEntryExtensions: Set<String> = ["json", "png"]

    // 受信時の容量上限（ZIP爆弾・巨大ファイル対策）
    static let maxArchiveBytes = 25 * 1024 * 1024
    static let maxJSONBytes = 64 * 1024
    static let maxStickerPNGBytes = 15 * 1024 * 1024
    static let maxThumbnailPNGBytes = 2 * 1024 * 1024

    // 受信時の画像ピクセルサイズ上限
    static let maxStickerPixelDimension = 4096
    static let maxThumbnailPixelDimension = 2048

    static let integrityAlgorithm = "SHA-256"

    /// エントリ名ごとの展開後サイズ上限
    static func maxBytes(forEntryName name: String) -> Int {
        switch name {
        case stickerEntryName: return maxStickerPNGBytes
        case thumbnailEntryName: return maxThumbnailPNGBytes
        default: return maxJSONBytes
        }
    }

    /// SHA-256 を小文字16進文字列で返す
    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// ZIP内 manifest.json の内容
struct StickerTradeManifest: Codable {
    var formatVersion: Int
    /// 送信元端末でのシールID（参考情報。受信側では衝突を避けるため必ず新しいIDを採番する）
    var stickerID: UUID
    var authorDisplayName: String
    var createdAt: Date
    var exportedAt: Date
}

/// ZIP内 integrity.json の内容
struct StickerTradeIntegrity: Codable {
    /// 現状 "SHA-256" 固定
    var algorithm: String
    /// エントリ名 → SHA-256（16進）。integrity.json 自身は含まない。
    var files: [String: String]
}
