//
//  TextStickerCreateView.swift
//  Stekki
//
//  文字を入力してテキストシールを作る画面。Instagramストーリーの文字編集を参考に、
//  フォントは横スクロールのカルーセルから選び、色はスウォッチをタップで素早く変えられ、
//  文字の背景プレート（IGの「A」ボタン相当）も付けられる。
//  さらに「文字の形」でアーチ・波・ふくらみの変形と、その強さを調整できる。
//

import SwiftUI
import SwiftData

struct TextStickerCreateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TextStickerCreateViewModel?

    @State private var text = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var selectedFont: StickerTextFont = .rounded
    @State private var textColor: Color = .black
    @State private var hasStroke = true
    @State private var strokeColor: Color = .white
    @State private var strokeWidth: Double = 3
    @State private var textStyle: StickerTextStyle = .plain
    @State private var styleIntensity: Double = 0.5
    @State private var hasPlate = false
    @State private var plateColor: Color = .white

    @State private var authorDisplayName = "自分"
    @State private var wasReceived = false
    @State private var receivedFrom = ""
    @State private var receivedAt = Date.now

    /// Instagram風のクイックカラースウォッチ（タップで即反映。細かい色はColorPickerで）
    private static let colorSwatches: [Color] = [
        .black, .white, .red, .orange, .yellow, .green, .mint, .cyan, .blue, .purple, .pink, .brown,
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    previewArea
                }
                .listRowBackground(Color.clear)
                // 文字入力欄以外の場所なので、タップしたらキーボードを閉じてよい。
                .dismissesKeyboardOnTap($isTextFieldFocused)

                Section("テキスト") {
                    TextField("シールにする文字を入力", text: $text, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($isTextFieldFocused)

                    fontCarousel
                }

                Section("文字の形") {
                    Picker("スタイル", selection: $textStyle.animation()) {
                        ForEach(StickerTextStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                    if textStyle != .plain {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("強さ")
                                Spacer()
                                Text("\(Int(styleIntensity * 100))%")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $styleIntensity, in: -1...1)
                            Text(textStyle.intensityHint)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .dismissesKeyboardOnTap($isTextFieldFocused)

                Section("色") {
                    colorSwatchRow
                    ColorPicker("文字色", selection: $textColor, supportsOpacity: false)
                    Toggle("文字の背景をつける", isOn: $hasPlate.animation())
                    if hasPlate {
                        ColorPicker("背景の色", selection: $plateColor, supportsOpacity: false)
                    }
                }
                .dismissesKeyboardOnTap($isTextFieldFocused)

                Section {
                    Toggle("縁取りをつける", isOn: $hasStroke.animation())
                    if hasStroke {
                        ColorPicker("縁取りの色", selection: $strokeColor, supportsOpacity: false)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("縁取りの太さ")
                                Spacer()
                                Text(String(format: "%.1fpt", strokeWidth))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $strokeWidth, in: 0.5...6)
                        }
                    }
                }
                .dismissesKeyboardOnTap($isTextFieldFocused)

                if let viewModel, viewModel.canSave {
                    Section("シールについて") {
                        TextField("作成者表示名", text: $authorDisplayName)
                        Toggle("交換で受け取った", isOn: $wasReceived.animation())
                        if wasReceived {
                            TextField("受取元（相手のニックネームなど）", text: $receivedFrom)
                            DatePicker("受取日時", selection: $receivedAt, displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                }

                if let message = viewModel?.errorMessage {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                    }
                }
            }
            // スクロールを始めた瞬間にもキーボードを閉じる（上記のタップに加えての保険）。
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("テキストシールを作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("トレイに追加") {
                        viewModel?.saveSticker(
                            authorDisplayName: authorDisplayName,
                            wasReceived: wasReceived,
                            receivedFrom: receivedFrom,
                            receivedAt: receivedAt
                        )
                        dismiss()
                    }
                    .disabled(viewModel?.canSave != true)
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = TextStickerCreateViewModel(modelContext: modelContext)
                }
                refreshPreview()
            }
            .onChange(of: text) { _, _ in refreshPreview() }
            .onChange(of: selectedFont) { _, _ in refreshPreview() }
            .onChange(of: textColor) { _, _ in refreshPreview() }
            .onChange(of: hasStroke) { _, _ in refreshPreview() }
            .onChange(of: strokeColor) { _, _ in refreshPreview() }
            .onChange(of: strokeWidth) { _, _ in refreshPreview() }
            .onChange(of: textStyle) { _, _ in refreshPreview() }
            .onChange(of: styleIntensity) { _, _ in refreshPreview() }
            .onChange(of: hasPlate) { _, _ in refreshPreview() }
            .onChange(of: plateColor) { _, _ in refreshPreview() }
        }
    }

    private func refreshPreview() {
        viewModel?.updatePreview(
            text: text,
            font: selectedFont,
            textColor: textColor,
            strokeColor: strokeColor,
            strokeWidth: hasStroke ? strokeWidth : 0,
            style: textStyle,
            styleIntensity: styleIntensity,
            plateColor: hasPlate ? plateColor : nil
        )
    }

    /// Instagram風の横スクロールフォントカルーセル。各チップはそのフォント自身で描画する。
    private var fontCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StickerTextFont.allCases) { font in
                    Button {
                        selectedFont = font
                    } label: {
                        Text(font.displayName)
                            .font(font.previewFont)
                            .foregroundStyle(selectedFont == font ? Color.accentColor : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(
                                    selectedFont == font
                                        ? Color.accentColor.opacity(0.18)
                                        : Color(.tertiarySystemFill)
                                )
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    selectedFont == font ? Color.accentColor : .clear,
                                    lineWidth: 1.5
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// タップで文字色を即切り替えるスウォッチの行
    private var colorSwatchRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(Self.colorSwatches.enumerated()), id: \.offset) { _, color in
                    Button {
                        textColor = color
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 1))
                            .overlay {
                                if color == textColor {
                                    Circle().strokeBorder(Color.accentColor, lineWidth: 2.5)
                                        .padding(-3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 3)
        }
    }

    @ViewBuilder
    private var previewArea: some View {
        ZStack {
            CheckerboardBackground()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            if let image = viewModel?.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(20)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "textformat")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("文字を入力するとシールになります")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(30)
            }
        }
        .frame(height: 220)
        .padding(.vertical, 8)
    }
}

private extension View {
    /// このビュー内をタップしたら、渡された `FocusState` を解除してキーボードを閉じる。
    /// `.simultaneousGesture` を使うことで、内側のボタンやピッカーなど自身のタップ処理を
    /// 妨げずに追加できる（`TextField` を含むセクションには付けないこと。タップして
    /// フォーカスを得ようとした瞬間にこのジェスチャが同時発火し、逆に閉じてしまうため）。
    func dismissesKeyboardOnTap(_ focus: FocusState<Bool>.Binding) -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                focus.wrappedValue = false
            }
        )
    }
}
