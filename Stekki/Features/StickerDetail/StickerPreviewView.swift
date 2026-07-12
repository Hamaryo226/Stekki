//
//  StickerPreviewView.swift
//  Stekki
//
//  シール詳細で写真をタップした際のフルスクリーンプレビュー。
//  ピンチで拡大縮小、ドラッグでパン（拡大時）、下方向スワイプで閉じる、
//  ダブルタップで倍率をリセットできる。
//

import SwiftUI

struct StickerPreviewView: View {
    let fileName: String?

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dismissDragOffset: CGFloat = 0

    private var backgroundOpacity: Double {
        1 - min(abs(dismissDragOffset) / 300, 0.7)
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    if scale <= 1.01 { dismiss() }
                }

            StickerImageView(fileName: fileName)
                .padding(24)
                .scaleEffect(scale)
                .offset(x: offset.width, y: offset.height + dismissDragOffset)
                .gesture(magnifyGesture)
                .simultaneousGesture(dragGesture)
                .onTapGesture(count: 2) {
                    withAnimation(StekkiSpring.snapBack) {
                        scale = 1
                        lastScale = 1
                        offset = .zero
                        lastOffset = .zero
                    }
                }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white, .black.opacity(0.35))
            }
            .padding(20)
        }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = (lastScale * value).clamped(to: 1...4)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.01 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                } else {
                    dismissDragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if scale > 1.01 {
                    lastOffset = offset
                } else if abs(value.translation.height) > 120 {
                    dismiss()
                } else {
                    withAnimation(StekkiSpring.snapBack) {
                        dismissDragOffset = 0
                    }
                }
            }
    }
}
