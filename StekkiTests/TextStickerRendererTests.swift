//
//  TextStickerRendererTests.swift
//  StekkiTests
//
//  テキストシールの描画（アーチ・波・ふくらみ・背景プレートを含む）のテスト。
//  画像の中身までは検証せず、生成可否とサイズの関係で確認する。
//

import Testing
import UIKit
@testable import Stekki

struct TextStickerRendererTests {

    private func render(
        _ text: String,
        style: StickerTextStyle = .plain,
        intensity: CGFloat = 0,
        plate: UIColor? = nil
    ) -> UIImage? {
        TextStickerRenderer.render(
            text: text,
            font: .system,
            textColor: .black,
            strokeColor: .white,
            strokeWidth: 2,
            style: style,
            styleIntensity: intensity,
            plateColor: plate
        )
    }

    @Test func rendersPlainText() {
        let image = render("こんにちは")
        #expect(image != nil)
    }

    @Test func emptyOrWhitespaceTextReturnsNil() {
        #expect(render("") == nil)
        #expect(render("   \n  ") == nil)
    }

    @Test func rendersAllStylesAtVariousIntensities() {
        for style in StickerTextStyle.allCases {
            for intensity: CGFloat in [-1, -0.5, 0.5, 1] {
                let image = render("Stekki", style: style, intensity: intensity)
                #expect(image != nil, "style=\(style.rawValue) intensity=\(intensity)")
            }
        }
    }

    @Test func archTextIsTallerThanPlain() throws {
        let plain = try #require(render("ABCDEFGH"))
        let arch = try #require(render("ABCDEFGH", style: .arch, intensity: 1))
        // 弧に沿って上下に広がるぶん、キャンバスの高さが増えるはず
        #expect(arch.size.height > plain.size.height)
    }

    @Test func nearZeroIntensityFallsBackToPlain() throws {
        let plain = try #require(render("ABC"))
        let almostPlain = try #require(render("ABC", style: .arch, intensity: 0.01))
        #expect(plain.size == almostPlain.size)
    }

    @Test func plateEnlargesCanvas() throws {
        let bare = try #require(render("ABC"))
        let plated = try #require(render("ABC", plate: .white))
        #expect(plated.size.width > bare.size.width)
        #expect(plated.size.height > bare.size.height)
    }

    @Test func multilineIsTallerThanSingleLine() throws {
        let single = try #require(render("あいう"))
        let multi = try #require(render("あいう\nかきく"))
        #expect(multi.size.height > single.size.height)
    }

    @Test func alignmentDoesNotChangeCanvasSize() throws {
        // 行揃えは行の配置だけを変え、キャンバス全体の大きさは変えない
        func renderAligned(_ alignment: NSTextAlignment) -> UIImage? {
            TextStickerRenderer.render(
                text: "みじかい\nながいながい行",
                font: .system,
                textColor: .black,
                strokeColor: .white,
                strokeWidth: 2,
                alignment: alignment
            )
        }
        let center = try #require(renderAligned(.center))
        let left = try #require(renderAligned(.left))
        let right = try #require(renderAligned(.right))
        #expect(left.size == center.size)
        #expect(right.size == center.size)
    }
}
