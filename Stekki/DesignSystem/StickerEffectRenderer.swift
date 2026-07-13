//
//  StickerEffectRenderer.swift
//  Stekki
//
//  「白フチ」エフェクトの画像を生成する。透明PNGのアルファをCore Imageの
//  モルフォロジー膨張（CIMorphologyMaximum）で外側へ広げ、その形の白い
//  シルエットを元画像の背後に敷くことで、IGのステッカーのような
//  被写体の形に沿った縁取りになる。生成結果はメモリキャッシュする。
//  グローは画像加工ではなくSwiftUIのシャドウで表現するため、ここでは扱わない。
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum StickerEffectRenderer {
    private static let ciContext = CIContext()
    private static let cache = NSCache<NSString, UIImage>()

    private static func cacheKey(for fileName: String) -> NSString {
        "whiteOutline:\(fileName)" as NSString
    }

    /// 白フチ付きの画像を返す（初回生成後はキャッシュ）。生成に失敗した場合は nil。
    static func whiteOutlinedImage(for fileName: String) -> UIImage? {
        let key = cacheKey(for: fileName)
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let base = StickerImageCache.shared.image(for: fileName),
              let outlined = makeWhiteOutline(base) else {
            return nil
        }
        cache.setObject(outlined, forKey: key)
        return outlined
    }

    /// 元画像が差し替わった（テキストシールの再編集等）場合に呼ぶ
    static func invalidate(fileName: String) {
        cache.removeObject(forKey: cacheKey(for: fileName))
    }

    private static func makeWhiteOutline(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let input = CIImage(cgImage: cgImage)
        guard input.extent.width > 0, input.extent.height > 0 else { return nil }

        // フチの太さは画像の大きさに比例させ、表示サイズによらず見た目の比率を揃える
        let radius = max(input.extent.width, input.extent.height) * 0.035

        let dilate = CIFilter.morphologyMaximum()
        dilate.inputImage = input
        dilate.radius = Float(radius)
        guard let dilated = dilate.outputImage else { return nil }

        // 膨張した形のアルファ × 白ベタ = 白いシルエット（sourceAtop は
        // 背景のアルファを保ったまま、その上にソースを重ねる合成）
        let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1))
            .cropped(to: dilated.extent)
        let silhouette = white.applyingFilter(
            "CISourceAtopCompositing",
            parameters: [kCIInputBackgroundImageKey: dilated]
        )

        let composed = input.composited(over: silhouette)
        let extent = composed.extent.integral
        guard let output = ciContext.createCGImage(composed, from: extent) else { return nil }
        return UIImage(cgImage: output, scale: image.scale, orientation: .up)
    }
}
