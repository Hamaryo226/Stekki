//
//  StickerTradeReceiveView.swift
//  Stekki
//
//  受信した .stickertrade のプレビュー画面。ここでは自動保存せず、
//  利用者が「トレイに追加」を押したときにだけ画像を保存して Sticker を作成する。
//  閉じた（受け取らなかった）場合は何も残らない。
//

import SwiftUI
import SwiftData

struct StickerTradeReceiveView: View {
    let payload: StickerTradePayload

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var receivedFrom: String
    @State private var errorMessage: String?

    init(payload: StickerTradePayload) {
        self.payload = payload
        // 受取元はマニフェストの作成者名を初期値にし、その場で書き換えられるようにする
        _receivedFrom = State(initialValue: payload.manifest.authorDisplayName)
    }

    var body: some View {
        NavigationStack {
            Form {
                previewSection

                Section("シールについて") {
                    LabeledContent("作成者", value: payload.manifest.authorDisplayName)
                    LabeledContent("作成日時") {
                        Text(payload.manifest.createdAt, format: .dateTime.year().month().day().hour().minute())
                    }
                }

                Section {
                    TextField("相手のニックネームなど", text: $receivedFrom)
                } header: {
                    Text("受取元")
                } footer: {
                    Text("「トレイに追加」を押すと、このシールが未貼付トレイに保存されます。追加しない場合は何も保存されません。")
                }
            }
            .navigationTitle("シールを受け取る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("受け取らない") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("トレイに追加") { addToTray() }
                }
            }
            .alert(
                "保存に失敗しました",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var previewSection: some View {
        Section {
            HStack {
                Spacer()
                Image(uiImage: payload.stickerImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180)
                    .background(CheckerboardBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
    }

    private func addToTray() {
        do {
            let imageFileName = try StickerFileStore.save(pngData: payload.stickerPNGData)
            let thumbnailFileName = try? StickerFileStore.save(pngData: payload.thumbnailPNGData)

            let trimmedFrom = receivedFrom.trimmingCharacters(in: .whitespacesAndNewlines)
            // IDは必ずローカルで新規採番する。manifestのstickerIDをそのまま使うと、
            // 同じシールが往復した場合に @Attribute(.unique) の衝突で既存シールを上書きしうるため。
            let sticker = Sticker(
                imageFileName: imageFileName,
                thumbnailFileName: thumbnailFileName,
                createdAt: payload.manifest.createdAt,
                authorDisplayName: payload.manifest.authorDisplayName,
                receivedAt: .now,
                receivedFrom: trimmedFrom.isEmpty ? nil : trimmedFrom
            )
            modelContext.insert(sticker)
            try? modelContext.save()
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "画像の保存に失敗しました。"
        }
    }
}
