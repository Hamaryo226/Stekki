//
//  StickerDetailView.swift
//  Stekki
//
//  シール1枚の詳細。作成日時・作成者・受取日時/受取元・現在のページと位置・貼付履歴を表示する。
//

import SwiftUI
import SwiftData

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

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                metadataSection
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

    @ViewBuilder
    private var currentLocationSection: some View {
        Section("現在の場所") {
            if let placement = sticker.placement, let page = placement.page {
                LabeledContent("シール帳", value: page.book?.title ?? "-")
                LabeledContent("ページ", value: page.displayName)
                LabeledContent("位置") {
                    Text("x: \(Int(placement.x * 100))% ・ y: \(Int(placement.y * 100))%")
                }
                LabeledContent("拡大 / 回転") {
                    Text("\(Int(placement.scale * 100))% ・ \(Int(placement.rotation * 180 / .pi))°")
                }
                LabeledContent("重なり順", value: "\(placement.zIndex)")

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
}
