//
//  StickerTransferItem.swift
//  Stekki
//
//  トレイ→ページへのドラッグ&ドロップで受け渡す最小限のペイロード（アプリ内完結・端末外へは出さない）。
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

struct StickerTransferItem: Codable, Transferable {
    let stickerID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .stekkiSticker)
    }
}

extension UTType {
    /// アプリ内ドラッグ&ドロップ専用の識別子。外部アプリとのやり取りは想定しない。
    static let stekkiSticker = UTType(exportedAs: "jp.hamaryo.stekki.sticker")
}
