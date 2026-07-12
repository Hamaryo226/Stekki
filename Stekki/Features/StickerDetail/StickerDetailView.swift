//
//  StickerDetailView.swift
//  Stekki
//
//  シール1枚の詳細。作成日時・作成者・受取日時/受取元・現在のページと位置・貼付履歴を表示する。
//

import SwiftUI
import SwiftData

/// 共有シートに渡す書き出し済みファイル（sheet(item:)用のIdentifiableラッパー）
private struct StickerTradeShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

struct StickerDetailView: View {
    let sticker: Sticker
    var onRemoveToTray: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: StickerDetailViewModel?

    @State private var isEditing = false
    @State private var authorDisplayName = ""
    @State private var wasReceived = false
    @State private var receivedFrom = ""
    @State private var receivedAt = Date.now
    @State private var isShowingDeleteConfirm = false
    @State private var isShowingFullPreview = false
    @State private var shareItem: StickerTradeShareItem?
    @State private var lastExportedFileURL: URL?
    @State private var exportErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                metadataSection
                sendSection
                currentLocationSection
                historySection
            }
            .navigationTitle("シールの詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "編集") {
                        if isEditing {
                            viewModel?.updateMetadata(
                                authorDisplayName: authorDisplayName,
                                wasReceived: wasReceived,
                                receivedFrom: receivedFrom,
                                receivedAt: receivedAt
                            )
                        }
                        isEditing.toggle()
                    }
                }
            }
            .confirmationDialog(
                "このシールを完全に削除しますか？画像と履歴も削除され、元に戻せません。",
                isPresented: $isShowingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("完全に削除する", role: .destructive) {
                    viewModel?.deletePermanently()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $isShowingFullPreview) {
                StickerPreviewView(fileName: sticker.imageFileName)
            }
            .sheet(item: $shareItem, onDismiss: {
                // 一時ディレクトリに書き出した .stickertrade を掃除する
                // （onDismiss時点でshareItemはnilなので、URLは別途保持しておいたものを使う）
                if let url = lastExportedFileURL {
                    try? FileManager.default.removeItem(at: url)
                    lastExportedFileURL = nil
                }
            }) { item in
                ActivityShareSheet(activityItems: [item.url])
                    .presentationDetents([.medium, .large])
            }
            .alert(
                "送信ファイルを作成できませんでした",
                isPresented: Binding(
                    get: { exportErrorMessage != nil },
                    set: { if !$0 { exportErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage ?? "")
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = StickerDetailViewModel(sticker: sticker, modelContext: modelContext)
            }
            authorDisplayName = sticker.authorDisplayName
            wasReceived = sticker.receivedAt != nil || sticker.receivedFrom != nil
            receivedFrom = sticker.receivedFrom ?? ""
            receivedAt = sticker.receivedAt ?? .now
        }
    }

    private var previewSection: some View {
        Section {
            HStack {
                Spacer()
                Button {
                    isShowingFullPreview = true
                } label: {
                    StickerImageView(fileName: sticker.imageFileName)
                        .frame(width: 140, height: 140)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption)
                                .padding(6)
                                .background(.thinMaterial, in: Circle())
                                .offset(x: -4, y: -4)
                        }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
    }

    private var metadataSection: some View {
        Section("シールについて") {
            LabeledContent("作成日時") {
                Text(sticker.createdAt, format: .dateTime.year().month().day().hour().minute())
            }

            if isEditing {
                TextField("作成者表示名", text: $authorDisplayName)
                Toggle("交換で受け取った", isOn: $wasReceived.animation())
                if wasReceived {
                    TextField("受取元（相手のニックネームなど）", text: $receivedFrom)
                    DatePicker("受取日時", selection: $receivedAt, displayedComponents: [.date, .hourAndMinute])
                }
            } else {
                LabeledContent("作成者表示名", value: sticker.authorDisplayName)
                if let receivedAt = sticker.receivedAt {
                    LabeledContent("受取日時") {
                        Text(receivedAt, format: .dateTime.year().month().day().hour().minute())
                    }
                }
                LabeledContent("受取元", value: sticker.receivedFrom ?? "自分で作成")
            }
        }
    }

    private var sendSection: some View {
        Section {
            Button {
                sendSticker()
            } label: {
                Label("このシールを送る", systemImage: "square.and.arrow.up")
            }
        } footer: {
            Text("AirDropなどで .stickertrade ファイルとして送れます。相手が受け取ったかどうかは確認できないため、送ってもこのシールは手元に残ります。")
        }
    }

    /// シールを .stickertrade に書き出して共有シート（AirDrop等）を開く
    private func sendSticker() {
        do {
            let url = try StickerTradeExporter.exportFile(for: sticker)
            lastExportedFileURL = url
            shareItem = StickerTradeShareItem(url: url)
        } catch {
            exportErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? "送信用ファイルの作成に失敗しました。"
        }
    }

    @ViewBuilder
    private var currentLocationSection: some View {
        Section("現在の場所") {
            if let placement = sticker.placement, let page = placement.page {
                LabeledContent("シール帳", value: page.book?.title ?? "-")
                LabeledContent("ページ", value: page.displayName)
                LabeledContent("位置") {
                    Text(positionText(for: placement))
                }
                LabeledContent("拡大 / 回転") {
                    Text(transformText(for: placement))
                }
                LabeledContent("重なり順", value: "\(placement.zIndex)")
                LabeledContent("左右反転", value: placement.isFlippedHorizontally ? "する" : "しない")
                LabeledContent("影", value: placement.hasShadow ? "あり" : "なし")

                Button(role: .destructive) {
                    onRemoveToTray()
                } label: {
                    Label("トレイに戻す", systemImage: "tray.and.arrow.down")
                }
            } else {
                Label("未貼付トレイにあります", systemImage: "tray")
                    .foregroundStyle(.secondary)
            }
        }

        Section {
            Button(role: .destructive) {
                isShowingDeleteConfirm = true
            } label: {
                Label("シールを完全に削除", systemImage: "trash")
            }
        }
    }

    private var historySection: some View {
        Section("貼付履歴") {
            if sticker.sortedHistory.isEmpty {
                Text("まだ履歴はありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sticker.sortedHistory) { entry in
                    PlacementHistoryRow(entry: entry)
                }
            }
        }
    }

    // MARK: - 表示用テキスト
    // Note: これらの数値計算を `Text` の文字列補間内に直接書くと、Swiftの型推論が
    // 複雑になりすぎてビルドが極端に遅くなる／失敗することがあるため、
    // 明示的な型を持つ独立したヘルパーに分離している。

    private func positionText(for placement: StickerPlacement) -> String {
        let xPercent: Int = Int(placement.x * 100)
        let yPercent: Int = Int(placement.y * 100)
        return "x: \(xPercent)% ・ y: \(yPercent)%"
    }

    private func transformText(for placement: StickerPlacement) -> String {
        let scalePercent: Int = Int(placement.scale * 100)
        let rotationDegrees: Int = Int(placement.rotation * 180 / .pi)
        return "\(scalePercent)% ・ \(rotationDegrees)°"
    }
}
