//
//  TextStickerEditorView.swift
//  Stekki
//
//  Instagramストーリーの文字編集と同じ操作感のフルスクリーンエディタ。
//  - 画面中央でそのまま文字を入力する（キーボードを閉じると実際のシール描画でプレビュー）
//  - 左端の縦スライダーで文字サイズを変える（IGと同じ配置）
//  - 上部バー：行揃えの循環（左→中央→右）、背景プレート（IGの「A」ボタン）、完了
//  - 下部バー：フォント／カラー／縁取り／文字の形 をアイコンタブで切り替え
//  新規作成（editingSticker == nil）と、既存テキストシールの再編集の両方に使う。
//

import SwiftUI
import SwiftData
import UIKit

struct TextStickerEditorView: View {
    /// nil なら新規作成（保存時にトレイへ追加）。非nilならそのシールの文字を編集して画像を差し替える。
    let editingSticker: Sticker?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TextStickerEditorViewModel?

    @State private var spec: TextStickerSpec
    /// キーボードを閉じている間に表示する、実際のシール描画プレビュー
    @State private var previewImage: UIImage?
    @FocusState private var isTextFocused: Bool
    @State private var activeTool: EditorTool = .font
    @State private var colorTarget: ColorTarget = .text

    private enum EditorTool: CaseIterable {
        case font, color, stroke, shape

        var iconName: String {
            switch self {
            case .font: return "textformat"
            case .color: return "paintpalette.fill"
            case .stroke: return "pencil.and.outline"
            case .shape: return "water.waves"
            }
        }

        var label: String {
            switch self {
            case .font: return "フォント"
            case .color: return "カラー"
            case .stroke: return "縁取り"
            case .shape: return "形"
            }
        }
    }

    private enum ColorTarget: CaseIterable {
        case text, stroke, plate

        var label: String {
            switch self {
            case .text: return "文字"
            case .stroke: return "縁取り"
            case .plate: return "背景"
            }
        }
    }

    /// Instagram風のクイックカラースウォッチ（タップで即反映。細かい色はColorPickerで）
    private static let colorSwatches: [Color] = [
        .white, .black, .red, .orange, .yellow, .green, .mint, .cyan, .blue, .purple, .pink, .brown,
    ]

    init(editingSticker: Sticker? = nil) {
        self.editingSticker = editingSticker
        let restored = editingSticker?.textSpecJSON.flatMap { TextStickerSpec(json: $0) }
        _spec = State(initialValue: restored ?? .initial)
    }

    var body: some View {
        ZStack {
            // 背景。タップで「入力 ⇔ 仕上がりプレビュー」を切り替える（IGの画面タップと同じ感覚）
            LinearGradient(
                colors: [Color(white: 0.13), Color(white: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                isTextFocused.toggle()
            }

            VStack(spacing: 0) {
                topBar
                previewArea
                bottomTools
            }

            if let message = viewModel?.errorMessage {
                errorBanner(message)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if viewModel == nil {
                viewModel = TextStickerEditorViewModel(modelContext: modelContext)
            }
            refreshPreview()
            // fullScreenCover の表示アニメーションが落ち着いてからキーボードを出す
            Task {
                try? await Task.sleep(nanoseconds: 450_000_000)
                isTextFocused = true
            }
        }
        .onChange(of: spec) { _, _ in
            // 入力中はTextFieldがそのまま見えているので、閉じている間だけ描画し直す
            if !isTextFocused { refreshPreview() }
        }
        .onChange(of: isTextFocused) { _, focused in
            if !focused { refreshPreview() }
        }
    }

    private func refreshPreview() {
        previewImage = spec.render()
    }

    // MARK: - 上部バー

    private var alignmentIconName: String {
        switch spec.alignmentID {
        case "left": return "text.alignleft"
        case "right": return "text.alignright"
        default: return "text.aligncenter"
        }
    }

    private var topBar: some View {
        HStack(spacing: 20) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
            }
            .accessibilityLabel("閉じる")

            Spacer()

            Button {
                withAnimation(StekkiSpring.tap) { spec.cycleAlignment() }
            } label: {
                Image(systemName: alignmentIconName)
                    .font(.system(size: 17, weight: .semibold))
            }
            .accessibilityLabel("行揃えを切り替え")

            Button {
                withAnimation(StekkiSpring.tap) { spec.hasPlate.toggle() }
            } label: {
                Image(systemName: spec.hasPlate ? "a.square.fill" : "a.square")
                    .font(.system(size: 19, weight: .semibold))
            }
            .accessibilityLabel("文字の背景プレート")

            Spacer()

            Button {
                finish()
            } label: {
                Text("完了")
                    .font(.system(size: 17, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - 中央プレビュー（入力）

    private var swiftUIAlignment: TextAlignment {
        switch spec.alignmentID {
        case "left": return .leading
        case "right": return .trailing
        default: return .center
        }
    }

    /// 入力表示用のフォントサイズ。描画サイズ（36〜120pt）をそのまま使うと
    /// 画面に収まらないため、見た目の割合を保ったまま縮小して表示する。
    private var displayFontSize: CGFloat {
        CGFloat(spec.fontSize) * 0.55
    }

    private var previewArea: some View {
        ZStack {
            if isTextFocused {
                editingText
            } else if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 320, maxHeight: 300)
                    .padding(.horizontal, 44)
                    .onTapGesture { isTextFocused = true }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "textformat")
                        .font(.system(size: 40))
                    Text("タップして文字を入力")
                        .font(.footnote)
                }
                .foregroundStyle(.white.opacity(0.55))
                .contentShape(Rectangle())
                .onTapGesture { isTextFocused = true }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 左端の縦サイズスライダー（IGと同じ位置）
        .overlay(alignment: .leading) {
            VerticalFontSizeSlider(value: $spec.fontSize, range: TextStickerSpec.fontSizeRange)
                .padding(.leading, 6)
        }
    }

    private var editingText: some View {
        TextField("文字を入力", text: $spec.text, axis: .vertical)
            .focused($isTextFocused)
            .font(spec.font.swiftUIFont(size: displayFontSize))
            .foregroundStyle(Color(hex: spec.textColorHex))
            .tint(.white)
            .multilineTextAlignment(swiftUIAlignment)
            .lineLimit(1...5)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if spec.hasPlate {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: spec.plateColorHex))
                }
            }
            .padding(.horizontal, 48)
    }

    // MARK: - 下部ツール

    private var bottomTools: some View {
        VStack(spacing: 10) {
            Group {
                switch activeTool {
                case .font: fontCarousel
                case .color: colorTool
                case .stroke: strokeTool
                case .shape: shapeTool
                }
            }
            .frame(minHeight: 64)

            HStack(spacing: 0) {
                ForEach(EditorTool.allCases, id: \.self) { tool in
                    Button {
                        withAnimation(StekkiSpring.tap) {
                            activeTool = tool
                            // 形・縁取りは入力表示では見えないので、仕上がりプレビューへ切り替えて見せる
                            if tool == .shape || tool == .stroke {
                                isTextFocused = false
                            }
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tool.iconName)
                                .font(.system(size: 17, weight: .semibold))
                            Text(tool.label)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(activeTool == tool ? .white : .white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.black.opacity(0.35))
    }

    /// フォントカルーセル。各チップはそのフォント自身の見た目で表示する（IGと同じ）。
    private var fontCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StickerTextFont.allCases) { font in
                    Button {
                        withAnimation(StekkiSpring.tap) { spec.font = font }
                    } label: {
                        Text(font.displayName)
                            .font(font.previewFont)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(.white.opacity(spec.font == font ? 0.32 : 0.12))
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    spec.font == font ? .white : .clear,
                                    lineWidth: 1.5
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
    }

    private var colorTool: some View {
        VStack(spacing: 8) {
            // どの色を変えるかの切り替え（縁取り・背景を選ぶと自動でONになる）
            HStack(spacing: 8) {
                ForEach(ColorTarget.allCases, id: \.self) { target in
                    Button {
                        withAnimation(StekkiSpring.tap) {
                            colorTarget = target
                            if target == .stroke { spec.hasStroke = true }
                            if target == .plate { spec.hasPlate = true }
                        }
                    } label: {
                        Text(target.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(colorTarget == target ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(colorTarget == target ? .white : .white.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                ColorPicker("", selection: activeColorBinding, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 32)
                    .accessibilityLabel("その他の色")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(Self.colorSwatches.enumerated()), id: \.offset) { _, color in
                        swatchButton(color)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
    }

    private func swatchButton(_ color: Color) -> some View {
        let hex = color.hexRGBString
        return Button {
            activeColorBinding.wrappedValue = color
        } label: {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .overlay {
                    if hex == activeColorHex {
                        Circle().strokeBorder(.white, lineWidth: 2.5)
                            .padding(-3)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var activeColorHex: String {
        switch colorTarget {
        case .text: return spec.textColorHex
        case .stroke: return spec.strokeColorHex
        case .plate: return spec.plateColorHex
        }
    }

    private var activeColorBinding: Binding<Color> {
        switch colorTarget {
        case .text:
            return Binding(
                get: { Color(hex: spec.textColorHex) },
                set: { spec.textColorHex = $0.hexRGBString }
            )
        case .stroke:
            return Binding(
                get: { Color(hex: spec.strokeColorHex) },
                set: { spec.strokeColorHex = $0.hexRGBString }
            )
        case .plate:
            return Binding(
                get: { Color(hex: spec.plateColorHex) },
                set: { spec.plateColorHex = $0.hexRGBString }
            )
        }
    }

    private var strokeTool: some View {
        VStack(spacing: 8) {
            Toggle(isOn: $spec.hasStroke.animation()) {
                Text("縁取りをつける")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .tint(.white.opacity(0.4))

            if spec.hasStroke {
                HStack(spacing: 10) {
                    Text("太さ")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                    Slider(value: $spec.strokeWidth, in: 0.5...6)
                        .tint(.white)
                    Text(String(format: "%.1f", spec.strokeWidth))
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 6)
    }

    private var shapeTool: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(StickerTextStyle.allCases) { style in
                    Button {
                        withAnimation(StekkiSpring.tap) { spec.style = style }
                    } label: {
                        Text(style.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(spec.style == style ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(spec.style == style ? .white : .white.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            if spec.style != .plain {
                HStack(spacing: 10) {
                    Text("強さ")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                    Slider(value: $spec.styleIntensity, in: -1...1)
                        .tint(.white)
                    Text("\(Int(spec.styleIntensity * 100))%")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 44, alignment: .trailing)
                }
                Text(spec.style.intensityHint)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 6)
    }

    // MARK: - 完了

    private func finish() {
        // IGと同じく、空のまま完了したら何も作らずに閉じる
        // （既存シールの編集で空にした場合も、変更を捨てて元のまま残す）
        guard spec.hasRenderableText else {
            dismiss()
            return
        }
        guard let viewModel else { return }
        let succeeded: Bool
        if let editingSticker {
            succeeded = viewModel.update(sticker: editingSticker, spec: spec)
        } else {
            succeeded = viewModel.saveNew(spec: spec) != nil
        }
        if succeeded {
            dismiss()
        }
    }

    private func errorBanner(_ message: String) -> some View {
        VStack {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.orange.opacity(0.85), in: Capsule())
                .padding(.top, 56)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

/// IGの文字サイズスライダーと同じ、画面左端の縦スライダー。
/// 上へドラッグするほど大きくなる。トラックのどこを触ってもその位置の値になる。
private struct VerticalFontSizeSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    private let trackHeight: CGFloat = 200
    private let knobSize: CGFloat = 24

    private var fraction: CGFloat {
        CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 上が太く下が細い、IG風のテーパーしたトラック
            TaperedTrack()
                .fill(.white.opacity(0.35))
                .frame(width: 14, height: trackHeight)

            Circle()
                .fill(.white)
                .frame(width: knobSize, height: knobSize)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                .offset(y: (1 - fraction) * (trackHeight - knobSize))
        }
        .frame(width: 44, height: trackHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gestureValue in
                    let usable = trackHeight - knobSize
                    let y = (gestureValue.location.y - knobSize / 2).clamped(to: 0...usable)
                    let newFraction = 1 - Double(y / usable)
                    value = range.lowerBound + newFraction * (range.upperBound - range.lowerBound)
                }
        )
        .accessibilityLabel("文字サイズ")
        .accessibilityValue("\(Int(value))ポイント")
    }

    /// 上端が太く下端が細いトラック形状
    private struct TaperedTrack: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let topHalf = rect.width / 2
            let bottomHalf = rect.width / 8
            path.move(to: CGPoint(x: rect.midX - topHalf, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX + topHalf, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX + bottomHalf, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX - bottomHalf, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}
