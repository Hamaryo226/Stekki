//
//  StickerImageCache.swift
//  Stekki
//
//  端末内に保存されたシール画像をメモリキャッシュして再描画コストを下げる。
//

import UIKit

final class StickerImageCache {
    static let shared = StickerImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {}

    func image(for fileName: String) -> UIImage? {
        let key = fileName as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = StickerFileStore.loadImage(fileName: fileName) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    func invalidate(fileName: String) {
        cache.removeObject(forKey: fileName as NSString)
    }
}
