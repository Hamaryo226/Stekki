//
//  BackgroundRemover.swift
//  Stekki
//
//  Vision の被写体マスク生成 (iOS 17+) を使い、写真の背景を取り除いて
//  透明PNGのシール画像を作る。すべて端末上のオンデバイス処理で完結する。
//

import UIKit
import Vision
import CoreImage

enum BackgroundRemoverError: Error, LocalizedError {
    case invalidImage
    case noSubjectFound
    case processingFailed(detail: String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "画像を読み込めませんでした。"
        case .noSubjectFound:
            return "写真から被写体を検出できませんでした。被写体がはっきり写っている写真を選んでください。"
        case .processingFailed(let detail):
            var message = "背景の削除に失敗しました。(\(detail))"
            #if targetEnvironment(simulator)
            message += "\n※ 被写体の検出・切り抜き(Vision)はiOSシミュレータでは正しく動作しないことがあります。実機でお試しください。"
            #endif
            return message
        }
    }
}

enum BackgroundRemover {

    /// 写真から被写体を切り抜き、背景が透明なPNGデータを生成する。
    /// - Note: `VNGenerateForegroundInstanceMaskRequest` は完全にオンデバイスで処理され、
    ///   ネットワーク通信やサーバーは一切利用しない。
    /// - Important: このAPIはNeural Engineに依存しており、**iOSシミュレータでは失敗しやすい**ことが
    ///   知られている（Appleの既知の制約）。うまくいかない場合はまず実機で試すこと。
    static func makeTransparentSticker(from image: UIImage) async throws -> Data {
        guard let cgImage = image.fixedOrientation()?.cgImage ?? image.cgImage else {
            throw BackgroundRemoverError.invalidImage
        }

        return try await Task.detached(priority: .userInitiated) {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNGenerateForegroundInstanceMaskRequest()

            do {
                try handler.perform([request])
            } catch {
                logFailure("VNImageRequestHandler.perform", error)
                throw BackgroundRemoverError.processingFailed(detail: error.localizedDescription)
            }

            guard let result = request.results?.first, !result.allInstances.isEmpty else {
                throw BackgroundRemoverError.noSubjectFound
            }

            let maskedPixelBuffer: CVPixelBuffer
            do {
                maskedPixelBuffer = try result.generateMaskedImage(
                    ofInstances: result.allInstances,
                    from: handler,
                    croppedToInstancesExtent: true
                )
            } catch {
                logFailure("generateMaskedImage", error)
                throw BackgroundRemoverError.processingFailed(detail: error.localizedDescription)
            }

            let ciImage = CIImage(cvPixelBuffer: maskedPixelBuffer)
            let context = CIContext()
            guard let outputCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                logFailure("CIContext.createCGImage", nil)
                throw BackgroundRemoverError.processingFailed(detail: "画像の変換に失敗")
            }

            let resultImage = UIImage(cgImage: outputCGImage)
            guard let pngData = resultImage.pngData() else {
                logFailure("UIImage.pngData", nil)
                throw BackgroundRemoverError.processingFailed(detail: "PNGへの変換に失敗")
            }
            return pngData
        }.value
    }

    /// 背景を除去せず、写真をそのままPNG化してシールにする（背景除去トグルOFF時に使用）。
    /// Vision を使わないため、シミュレータでも常に成功する。
    static func makeOpaqueSticker(from image: UIImage) throws -> Data {
        let fixed = image.fixedOrientation() ?? image
        guard let pngData = fixed.pngData() else {
            throw BackgroundRemoverError.processingFailed(detail: "PNGへの変換に失敗")
        }
        return pngData
    }

    /// 画像の四隅を丸くする（角丸のアルファマスクを重ねる）。
    /// - Parameter fraction: 0.0（角丸なし）〜0.5（短辺の半分、正方形なら完全な円/角丸最大）
    static func applyCornerRadius(_ fraction: CGFloat, to pngData: Data) -> Data? {
        guard fraction > 0.001, let image = UIImage(data: pngData) else { return pngData }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return pngData }

        let radius = min(size.width, size.height) * fraction.clamped(to: 0...0.5)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let rounded = renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()
            image.draw(in: rect)
        }
        return rounded.pngData() ?? pngData
    }

    /// トレイ表示用の軽量サムネイル（長辺200pt程度）を生成する
    static func makeThumbnail(from pngData: Data, maxDimension: CGFloat = 200) -> Data? {
        guard let image = UIImage(data: pngData) else { return nil }
        let scale = min(1.0, maxDimension / max(image.size.width, image.size.height))
        guard scale < 1.0 else { return pngData }

        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize, format: {
            let format = UIGraphicsImageRendererFormat.default()
            format.opaque = false
            return format
        }())
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.pngData()
    }

    /// デバッグ用: Xcodeコンソールに失敗要因を出力する（本番挙動には影響しない）
    private static func logFailure(_ step: String, _ error: Error?) {
        if let error {
            print("[BackgroundRemover] \(step) failed: \(error)")
        } else {
            print("[BackgroundRemover] \(step) failed")
        }
    }
}

private extension UIImage {
    /// カメラロールの写真は orientation が normalized でないことがあるため、
    /// Vision に渡す前に向きを焼き込んでおく。
    func fixedOrientation() -> UIImage? {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
