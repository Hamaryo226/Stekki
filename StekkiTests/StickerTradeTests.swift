//
//  StickerTradeTests.swift
//  StekkiTests
//
//  .stickertrade（ZIP）フォーマットの生成・検証ロジックのテスト。
//  ファイルI/OやSwiftDataを使わず、Data上のラウンドトリップと改ざん検出を確認する。
//

import Testing
import Foundation
import UIKit
@testable import Stekki

struct StickerTradeTests {

    // MARK: - テスト用ヘルパー

    /// 小さな正方形の透明PNGを作る
    private func makePNGData(size: CGFloat = 16) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        let image = renderer.image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(x: 2, y: 2, width: size - 4, height: size - 4))
        }
        return image.pngData()!
    }

    /// エクスポータと同じ構成の .stickertrade データを組み立てる
    private func makeArchive(
        stickerPNG: Data,
        thumbnailPNG: Data,
        formatVersion: Int = StickerTradeFormat.formatVersion,
        tamper: ((inout [(name: String, data: Data)]) -> Void)? = nil
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let manifest = StickerTradeManifest(
            formatVersion: formatVersion,
            stickerID: UUID(),
            authorDisplayName: "テスト作成者",
            createdAt: .now,
            exportedAt: .now
        )
        let manifestData = try encoder.encode(manifest)
        let integrity = StickerTradeIntegrity(
            algorithm: StickerTradeFormat.integrityAlgorithm,
            files: [
                StickerTradeFormat.manifestEntryName: StickerTradeFormat.sha256Hex(manifestData),
                StickerTradeFormat.stickerEntryName: StickerTradeFormat.sha256Hex(stickerPNG),
                StickerTradeFormat.thumbnailEntryName: StickerTradeFormat.sha256Hex(thumbnailPNG),
            ]
        )
        let integrityData = try encoder.encode(integrity)

        var entries: [(name: String, data: Data)] = [
            (StickerTradeFormat.manifestEntryName, manifestData),
            (StickerTradeFormat.stickerEntryName, stickerPNG),
            (StickerTradeFormat.thumbnailEntryName, thumbnailPNG),
            (StickerTradeFormat.integrityEntryName, integrityData),
        ]
        tamper?(&entries)
        return ZipArchiveWriter.makeArchive(entries: entries)
    }

    // MARK: - ZIPの読み書き

    @Test func zipRoundTrip() throws {
        let payloads: [(name: String, data: Data)] = [
            ("a.json", Data("{\"hello\":\"world\"}".utf8)),
            ("b.png", makePNGData()),
        ]
        let archive = ZipArchiveWriter.makeArchive(entries: payloads)
        let reader = try ZipArchiveReader(data: archive)

        #expect(reader.entries.count == 2)
        for (index, entry) in reader.entries.enumerated() {
            #expect(entry.name == payloads[index].name)
            let extracted = try reader.extractData(of: entry)
            #expect(extracted == payloads[index].data)
        }
    }

    @Test func zipRejectsGarbage() {
        #expect(throws: (any Error).self) {
            _ = try ZipArchiveReader(data: Data(repeating: 0xAB, count: 128))
        }
    }

    // MARK: - .stickertrade の検証

    @Test func importValidArchiveSucceeds() throws {
        let archive = try makeArchive(stickerPNG: makePNGData(size: 32), thumbnailPNG: makePNGData(size: 8))
        let payload = try StickerTradeImporter.importArchive(archive)

        #expect(payload.manifest.authorDisplayName == "テスト作成者")
        #expect(payload.stickerImage.cgImage?.width == 32)
    }

    @Test func importDetectsTamperedStickerPNG() throws {
        // integrity.json 作成後に sticker.png の1バイトを書き換える → SHA-256不一致で拒否されるはず
        let archive = try makeArchive(
            stickerPNG: makePNGData(),
            thumbnailPNG: makePNGData(size: 8),
            tamper: { entries in
                var corrupted = entries[1].data
                let index = corrupted.count - 1
                corrupted[index] ^= 0xFF
                entries[1] = (entries[1].name, corrupted)
            }
        )
        // 注: CRC32はZipArchiveWriterが改ざん後のデータから計算するためZIPとしては正常。
        // その先のSHA-256照合で検出されることを確認する。
        #expect(throws: StickerTradeImportError.self) {
            _ = try StickerTradeImporter.importArchive(archive)
        }
    }

    @Test func importRejectsWrongEntryCount() throws {
        let archive = try makeArchive(
            stickerPNG: makePNGData(),
            thumbnailPNG: makePNGData(size: 8),
            tamper: { entries in
                entries.append(("extra.txt", Data("unexpected".utf8)))
            }
        )
        #expect(throws: StickerTradeImportError.self) {
            _ = try StickerTradeImporter.importArchive(archive)
        }
    }

    @Test func importRejectsUnknownEntryName() throws {
        let archive = try makeArchive(
            stickerPNG: makePNGData(),
            thumbnailPNG: makePNGData(size: 8),
            tamper: { entries in
                entries[1] = ("sticker.jpg", entries[1].data)
            }
        )
        #expect(throws: StickerTradeImportError.self) {
            _ = try StickerTradeImporter.importArchive(archive)
        }
    }

    @Test func importRejectsNewerFormatVersion() throws {
        let archive = try makeArchive(
            stickerPNG: makePNGData(),
            thumbnailPNG: makePNGData(size: 8),
            formatVersion: StickerTradeFormat.formatVersion + 1
        )
        #expect(throws: StickerTradeImportError.self) {
            _ = try StickerTradeImporter.importArchive(archive)
        }
    }

    @Test func importRejectsNonPNGPayload() throws {
        // integrity上のハッシュは一致するがPNGシグネチャを持たない中身 → 画像検証で拒否されるはず
        let archive = try makeArchive(
            stickerPNG: Data("これはPNGではない".utf8),
            thumbnailPNG: makePNGData(size: 8)
        )
        #expect(throws: StickerTradeImportError.self) {
            _ = try StickerTradeImporter.importArchive(archive)
        }
    }
}
