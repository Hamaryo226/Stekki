//
//  StickerFileStore.swift
//  Stekki
//
//  シール画像（透明PNG）を端末内のApplication Supportディレクトリに保存・読込・削除する。
//  サーバーやiCloudは使用せず、常にオンデバイスで完結する。
//

import Foundation
import UIKit

enum StickerFileStoreError: Error, LocalizedError {
    case encodingFailed
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "画像をPNGに変換できませんでした。"
        case .writeFailed(let error):
            return "画像の保存に失敗しました: \(error.localizedDescription)"
        }
    }
}

/// シール画像ファイルの保存先を管理する。
/// - Note: `Sticker.imageFileName` にはファイル名のみを保存し、絶対パスは保存しない
///   （サンドボックスパスはインストールごとに変わりうるため、常に実行時に解決する）。
enum StickerFileStore {

    /// シール画像を保存しているディレクトリ（なければ作成する）
    static var directoryURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Stickers", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            // バックアップ対象から除外（端末内完結のシールデータをiCloudバックアップに含めるかは
            // 将来設定で選べるようにする想定。現状はデフォルトのまま = バックアップ対象に含める）
        }
        return dir
    }()

    /// ファイル名からフルパスURLを解決する
    static func url(for fileName: String) -> URL {
        directoryURL.appendingPathComponent(fileName)
    }

    /// UIImage をPNGとして保存し、生成したファイル名を返す
    @discardableResult
    static func save(image: UIImage, suggestedName: String? = nil) throws -> String {
        guard let data = image.pngData() else {
            throw StickerFileStoreError.encodingFailed
        }
        return try save(pngData: data, suggestedName: suggestedName)
    }

    /// 既にPNGエンコード済みのデータを保存し、生成したファイル名を返す
    @discardableResult
    static func save(pngData: Data, suggestedName: String? = nil) throws -> String {
        let fileName = "\(suggestedName ?? UUID().uuidString).png"
        let fileURL = url(for: fileName)
        do {
            try pngData.write(to: fileURL, options: .atomic)
        } catch {
            throw StickerFileStoreError.writeFailed(error)
        }
        return fileName
    }

    /// ファイル名から画像を読み込む
    static func loadImage(fileName: String?) -> UIImage? {
        guard let fileName else { return nil }
        return UIImage(contentsOfFile: url(for: fileName).path)
    }

    /// ファイルを削除する（存在しなくてもエラーにしない）
    static func delete(fileName: String?) {
        guard let fileName else { return }
        try? FileManager.default.removeItem(at: url(for: fileName))
    }
}
