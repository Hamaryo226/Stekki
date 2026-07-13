//
//  TextStickerSpecTests.swift
//  StekkiTests
//
//  テキストシールの文字仕様（TextStickerSpec）の保存・復元と、
//  そこからの描画、hex色変換の往復のテスト。
//

import Testing
import UIKit
import SwiftUI
@testable import Stekki

struct TextStickerSpecTests {

    private func makeSpec() -> TextStickerSpec {
        var spec = TextStickerSpec.initial
        spec.text = "こんにちは\nStekki"
        spec.fontID = StickerTextFont.cute.rawValue
        spec.fontSize = 96
        spec.textColorHex = "#FF3B30"
        spec.hasStroke = true
        spec.strokeColorHex = "#FFFFFF"
        spec.strokeWidth = 4.5
        spec.styleID = StickerTextStyle.arch.rawValue
        spec.styleIntensity = -0.7
        spec.hasPlate = true
        spec.plateColorHex = "#123456"
        spec.alignmentID = "right"
        return spec
    }

    @Test func jsonRoundTripPreservesAllFields() throws {
        let spec = makeSpec()
        let json = try #require(spec.encodedJSON())
        let restored = try #require(TextStickerSpec(json: json))
        #expect(restored == spec)
    }

    @Test func brokenJSONReturnsNil() {
        #expect(TextStickerSpec(json: "") == nil)
        #expect(TextStickerSpec(json: "{oops") == nil)
    }

    @Test func unknownFontAndStyleFallBackSafely() {
        var spec = TextStickerSpec.initial
        spec.fontID = "future-font"
        spec.styleID = "future-style"
        #expect(spec.font == .rounded)
        #expect(spec.style == .plain)
        #expect(spec.textAlignment == .center)
    }

    @Test func rendersImageFromSpec() throws {
        let image = try #require(makeSpec().render())
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }

    @Test func emptyTextSpecDoesNotRender() {
        var spec = TextStickerSpec.initial
        spec.text = "   \n "
        #expect(spec.hasRenderableText == false)
        #expect(spec.render() == nil)
    }

    @Test func alignmentCyclesLeftCenterRight() {
        var spec = TextStickerSpec.initial
        #expect(spec.alignmentID == "center")
        spec.cycleAlignment()
        #expect(spec.alignmentID == "right")
        spec.cycleAlignment()
        #expect(spec.alignmentID == "left")
        spec.cycleAlignment()
        #expect(spec.alignmentID == "center")
    }

    @Test func largerFontSizeProducesLargerSticker() throws {
        var small = TextStickerSpec.initial
        small.text = "ABC"
        small.fontSize = 48
        var large = small
        large.fontSize = 110
        let smallImage = try #require(small.render())
        let largeImage = try #require(large.render())
        #expect(largeImage.size.width > smallImage.size.width)
        #expect(largeImage.size.height > smallImage.size.height)
    }

    @Test func hexColorRoundTrip() {
        for hex in ["#000000", "#FFFFFF", "#FF3B30", "#123456"] {
            let color = Color(hex: hex)
            #expect(color.hexRGBString == hex)
        }
    }
}
