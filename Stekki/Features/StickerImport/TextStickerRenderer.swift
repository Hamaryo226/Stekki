//
//  TextStickerRenderer.swift
//  Stekki
//
//  文字列をフォント・文字色・縁取り・背景プレート付きで透明PNGに描画する。
//  「文字の形」（アーチ・波・ふくらみ）は1文字ずつ位置・回転・サイズを計算して
//  CGContext に描くことで実現する。まっすぐ（plain）の場合はカーニングが正確な
//  行単位の一括描画を使う。完全にオンデバイスの描画処理で、ネットワーク通信は発生しない。
//

import UIKit

enum TextStickerRenderer {

    /// 1文字ぶんの描画配置（行ローカル座標。原点は行の中心）
    private struct CharPlacement {
        let attributed: NSAttributedString
        let size: CGSize
        var center: CGPoint
        var rotation: CGFloat
    }

    /// テキストを描画し、透明背景のUIImageを返す。空文字の場合はnil。
    /// - Parameters:
    ///   - style: 文字の形（なし／アーチ／波／ふくらみ）
    ///   - styleIntensity: 形の強さ（-1〜+1）。絶対値がほぼ0なら「なし」と同じ。
    ///   - plateColor: 指定すると文字の背景に角丸のプレートを敷く（nilならプレートなし）
    ///   - alignment: 複数行のときの行揃え（左・中央・右のみ対応。それ以外は中央として扱う）
    static func render(
        text: String,
        font: StickerTextFont,
        textColor: UIColor,
        strokeColor: UIColor,
        strokeWidth: CGFloat,
        style: StickerTextStyle = .plain,
        styleIntensity: CGFloat = 0,
        plateColor: UIColor? = nil,
        fontSize: CGFloat = 72,
        alignment: NSTextAlignment = .center
    ) -> UIImage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 空行は除いて1行ずつ扱う（アーチ等は行単位で適用する）
        let lines = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        let uiFont = font.uiFont(size: fontSize)
        let effectiveStyle: StickerTextStyle = abs(styleIntensity) < 0.02 ? .plain : style

        var lineLayouts: [(placements: [CharPlacement], bounds: CGRect)] = []
        for line in lines {
            let layout = layoutLine(
                line,
                font: uiFont,
                textColor: textColor,
                strokeColor: strokeColor,
                strokeWidth: strokeWidth,
                style: effectiveStyle,
                intensity: styleIntensity,
                fontSize: fontSize
            )
            guard !layout.placements.isEmpty, layout.bounds.width > 0, layout.bounds.height > 0 else { continue }
            lineLayouts.append(layout)
        }
        guard !lineLayouts.isEmpty else { return nil }

        // 各行を縦に積み、全体のキャンバスサイズを決める
        let lineGap: CGFloat = fontSize * 0.18
        let contentWidth = lineLayouts.map(\.bounds.width).max() ?? 1
        let contentHeight = lineLayouts.map(\.bounds.height).reduce(0, +)
            + lineGap * CGFloat(lineLayouts.count - 1)

        let platePadding: CGFloat = plateColor != nil ? fontSize * 0.30 : 0
        let padding: CGFloat = max(strokeWidth, 4) + 14 + platePadding
        let canvasSize = CGSize(
            width: ceil(contentWidth) + padding * 2,
            height: ceil(contentHeight) + padding * 2
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { context in
            let ctx = context.cgContext

            if let plateColor {
                let plateRect = CGRect(
                    x: padding - platePadding,
                    y: padding - platePadding,
                    width: contentWidth + platePadding * 2,
                    height: contentHeight + platePadding * 2
                )
                plateColor.setFill()
                UIBezierPath(roundedRect: plateRect, cornerRadius: fontSize * 0.35).fill()
            }

            var lineTop = padding
            for layout in lineLayouts {
                // 行揃えに応じて行の水平位置を決め、行のバウンディング原点を打ち消して配置する
                let slack = contentWidth - layout.bounds.width
                let alignmentOffset: CGFloat
                switch alignment {
                case .left: alignmentOffset = 0
                case .right: alignmentOffset = slack
                default: alignmentOffset = slack / 2
                }
                let originX = padding + alignmentOffset - layout.bounds.minX
                let originY = lineTop - layout.bounds.minY
                for ch in layout.placements {
                    ctx.saveGState()
                    ctx.translateBy(x: originX + ch.center.x, y: originY + ch.center.y)
                    ctx.rotate(by: ch.rotation)
                    ch.attributed.draw(at: CGPoint(x: -ch.size.width / 2, y: -ch.size.height / 2))
                    ctx.restoreGState()
                }
                lineTop += layout.bounds.height + lineGap
            }
        }
    }

    // MARK: - 行レイアウト

    /// 1行ぶんの文字配置を計算する。座標は行ローカル（行の中心が原点）。
    private static func layoutLine(
        _ line: String,
        font: UIFont,
        textColor: UIColor,
        strokeColor: UIColor,
        strokeWidth: CGFloat,
        style: StickerTextStyle,
        intensity: CGFloat,
        fontSize: CGFloat
    ) -> (placements: [CharPlacement], bounds: CGRect) {
        // まっすぐの場合は行全体を1つの塊として描く（文字間のカーニングが正確なため）
        if style == .plain {
            let attributed = attributedString(line, font: font, textColor: textColor, strokeColor: strokeColor, strokeWidth: strokeWidth)
            let size = attributed.size()
            let placement = CharPlacement(attributed: attributed, size: size, center: .zero, rotation: 0)
            let bounds = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
            return ([placement], bounds)
        }

        // --- 文字ごとの attributed とサイズ ---
        let characters = Array(line)
        let count = characters.count
        var infos: [(attr: NSAttributedString, size: CGSize)] = []
        for (index, character) in characters.enumerated() {
            var charFont = font
            if style == .bulge, count > 1 {
                // 中央の文字ほど大きく（負の強さなら小さく＝くびれ）
                let t = CGFloat(index) / CGFloat(count - 1)               // 0...1
                let factor = 1 + intensity * 0.8 * cos((t - 0.5) * .pi)   // 中央で最大
                charFont = font.withSize(fontSize * max(0.35, factor))
            }
            let attr = attributedString(String(character), font: charFont, textColor: textColor, strokeColor: strokeColor, strokeWidth: strokeWidth)
            infos.append((attr, attr.size()))
        }
        let totalWidth = infos.reduce(CGFloat(0)) { $0 + $1.size.width }
        guard totalWidth > 1 else { return ([], .zero) }

        // --- 送り幅で並べてから、スタイルごとに位置・回転を決める ---
        var placements: [CharPlacement] = []
        var cursorX: CGFloat = 0
        for info in infos {
            let centerX = cursorX + info.size.width / 2 - totalWidth / 2  // 行中心が原点
            cursorX += info.size.width

            var center = CGPoint(x: centerX, y: 0)
            var rotation: CGFloat = 0

            switch style {
            case .plain, .bulge:
                break  // bulge はフォントサイズ差のみ。中心線に揃える。
            case .arch:
                // 弧の全角度は強さに比例（最大約±162°）。半径 = 弧長 ÷ 角度。
                // 正の強さで上向きアーチ（中央が持ち上がる）、負で下向き。
                let angleSpan = intensity * .pi * 0.9
                let radius = totalWidth / angleSpan
                let angle = centerX / radius
                center = CGPoint(x: radius * sin(angle), y: radius * (1 - cos(angle)))
                rotation = angle
            case .wave:
                // サインカーブに沿って上下させ、傾きに合わせて文字を少し回転させる
                let cycles: CGFloat = 1.2
                let amplitude = intensity * fontSize * 0.35
                let s = centerX / totalWidth                              // -0.5...0.5
                center.y = amplitude * sin(2 * .pi * cycles * s)
                let slope = amplitude * 2 * .pi * cycles / totalWidth * cos(2 * .pi * cycles * s)
                rotation = atan(slope)
            }

            placements.append(CharPlacement(attributed: info.attr, size: info.size, center: center, rotation: rotation))
        }

        // --- 回転を考慮したバウンディングボックスの合成 ---
        var bounds = CGRect.null
        for ch in placements {
            let halfWidth = (abs(ch.size.width * cos(ch.rotation)) + abs(ch.size.height * sin(ch.rotation))) / 2
            let halfHeight = (abs(ch.size.width * sin(ch.rotation)) + abs(ch.size.height * cos(ch.rotation))) / 2
            let rect = CGRect(
                x: ch.center.x - halfWidth,
                y: ch.center.y - halfHeight,
                width: halfWidth * 2,
                height: halfHeight * 2
            )
            bounds = bounds.union(rect)
        }
        return (placements, bounds.isNull ? .zero : bounds)
    }

    private static func attributedString(
        _ string: String,
        font: UIFont,
        textColor: UIColor,
        strokeColor: UIColor,
        strokeWidth: CGFloat
    ) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
        ]
        if strokeWidth > 0.01 {
            attributes[.strokeColor] = strokeColor
            // 負の値を指定すると「塗り + 縁取り」の両方が描画される（正の値だと縁取りのみになる）
            attributes[.strokeWidth] = -abs(strokeWidth)
        }
        return NSAttributedString(string: string, attributes: attributes)
    }
}
