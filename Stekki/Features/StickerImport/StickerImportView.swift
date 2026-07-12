//
//  StickerImportView.swift
//  Stekki
//
//  写真ライブラリからシールを作成する画面。選択 →（任意で）背景除去(Vision, オンデバイス) →
//  メタデータ入力 → 未貼付トレイへ保存、の流れ。
//

import SwiftUI
import UIKit
import PhotosUI
import SwiftData

struct StickerImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: StickerImportViewModel?

    @State private var selectedItem: PhotosPickerItem?
    @State private var removeBackground = true
    @State private var cornerRadiusFraction: Double = 0
    @State private var authorDisplayName = "自分"
    @State private var wasReceived = false
    @State private var receivedFrom = ""
    @State private var receivedAt = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    previewArea
                }
                .listRowBackground(Color.clear)

                Section {
                    Toggle("背景を自動で透明にする", isOn: $removeBackground)
                } footer: {
                    Text("被写体を自動検出して背景を切り抜きます。オフにすると写真をそのままシールにします。うまく切り抜けない場合はオフにしてみてください。")
                }

                if let viewModel, viewModel.canSave {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("角を丸くする")
                                Spacer()
                                Text(cornerRadiusPercentText)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(
                                value: $cornerRadiusFraction,
                                in: 0...0.5,
                                onEditingChanged: { isEditing in
                                    if !isEditing {
                                        viewModel.commitCornerRadius(cornerRadiusFraction)
                                    }
                                }
                            )
                        }
                    }
                }

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
            .navigationTitle("シールを作成")
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
                    viewModel = StickerImportViewModel(modelContext: modelContext)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    await viewModel?.process(
                        newItem,
                        removeBackground: removeBackground,
                        cornerRadiusFraction: cornerRadiusFraction
                    )
                }
            }
            .onChange(of: removeBackground) { _, newValue in
                guard let selectedItem else { return }
                Task {
                    await viewModel?.process(
                        selectedItem,
                        removeBackground: newValue,
                        cornerRadiusFraction: cornerRadiusFraction
                    )
                }
            }
            .onChange(of: cornerRadiusFraction) { _, newValue in
                viewModel?.previewCornerRadius(newValue)
            }
        }
    }

    /// 角丸スライダーの横に表示する「◯%」表示。
    /// - Note: この計算を `Text` の文字列補間内に直接書くと、Swiftの型推論が
    ///   複雑になりすぎてビルドが極端に遅くなる／失敗することがあるため、
    ///   明示的な型を持つ独立した計算プロパティに分離している。
    private var cornerRadiusPercentText: String {
        let ratio: Double = cornerRadiusFraction / 0.5
        let percent: Int = Int(ratio * 100)
        return "\(percent)%"
    }

    @ViewBuilder
    private var previewArea: some View {
        VStack(spacing: 16) {
            ZStack {
                CheckerboardBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                if viewModel?.isProcessing == true {
                    ProgressView(removeBackground ? "背景を切り抜いています…" : "読み込んでいます…")
                        .padding()
                } else if let image = viewModel?.processedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(20)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(
                            removeBackground
                                ? "写真を選ぶと自動で背景を透明にします"
                                : "写真を選ぶとそのままシールにします"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .padding(30)
                }
            }
            .frame(height: 260)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label(
                    viewModel?.processedImage == nil ? "写真を選ぶ" : "別の写真を選び直す",
                    systemImage: "photo.on.rectangle"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }
}
