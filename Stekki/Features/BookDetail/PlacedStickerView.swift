//
//  PlacedStickerView.swift
//  Stekki
//
//  ページ上に貼られた1枚のシール。編集モード中のみドラッグで移動、ピンチで拡縮、
//  ひねりで回転ができる。タップでの詳細表示はモードに関わらず常に可能。
//  Apple Fluid Interfaces指針に沿い、押した瞬間に反応し、ジェスチャの間は1:1で追従、
//  離した瞬間だけ軽くスプリングで収束させる。
//

import SwiftUI

struct PlacedStickerView: View {
    let placement: StickerPlacement
    let pageSize: CGSize
    /// true の間だけ移動・拡縮・回転ジェスチャが有効になる
    let isEditMode: Bool

    var onMove: (Double, Double) -> Void
    var onTransform: (Double, Double) -> Void
    var onBringToFront: () -> Void
    var onTap: () -> Void

    @State private var dragTranslation: CGSize = .zero
    @State private var liveScale: CGFloat = 1
    @State private var liveRotation: Angle = .zero
    @State private var isInteracting = false

    private let baseSize: CGFloat = 96

    /// placement.scale (Double, モデル保存値) とジェスチャ中の一時倍率をかけ合わせた表示用スケール
    private var displayScale: CGFloat {
        CGFloat(placement.scale) * liveScale
    }

    /// placement.rotation (Double・ラジアン, モデル保存値) とジェスチャ中の一時回転を足した表示用角度
    private var displayRotation: Angle {
        .radians(placement.rotation) + liveRotation
    }

    var body: some View {
        StickerImageView(fileName: placement.sticker?.thumbnailFileName ?? placement.sticker?.imageFileName)
            .frame(width: baseSize, height: baseSize)
            .scaleEffect(displayScale)
            .rotationEffect(displayRotation)
            .shadow(color: .black.opacity(isInteracting ? 0.22 : 0.12), radius: isInteracting ? 10 : 4, x: 0, y: isInteracting ? 6 : 2)
            .scaleEffect(isInteracting ? 1.06 : 1.0)
            .overlay(editModeIndicator)
            .position(
                x: CGFloat(placement.x) * pageSize.width + dragTranslation.width,
                y: CGFloat(placement.y) * pageSize.height + dragTranslation.height
            )
            .zIndex(Double(placement.zIndex))
            .animation(StekkiSpring.drag, value: isInteracting)
            .animation(StekkiSpring.standard, value: isEditMode)
            .gesture(dragGesture, including: isEditMode ? .all : .none)
            .simultaneousGesture(transformGesture, including: isEditMode ? .all : .none)
            .onTapGesture {
                onTap()
            }
            .accessibilityLabel("貼り付けられたシール")
            .accessibilityAddTraits(.isButton)
    }

    /// 編集モード中であることを示す、うっすらとした点線の枠
    @ViewBuilder
    private var editModeIndicator: some View {
        if isEditMode {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(.white.opacity(0.9))
                .scaleEffect(displayScale)
                .rotationEffect(displayRotation)
                .allowsHitTesting(false)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .onChanged { value in
                if !isInteracting {
                    isInteracting = true
                    onBringToFront()
                }
                dragTranslation = value.translation
            }
            .onEnded { value in
                let deltaX = Double(value.translation.width / max(pageSize.width, 1))
                let deltaY = Double(value.translation.height / max(pageSize.height, 1))
                let newX = (placement.x + deltaX).clamped(to: 0...1)
                let newY = (placement.y + deltaY).clamped(to: 0...1)
                onMove(newX, newY)
                dragTranslation = .zero
                isInteracting = false
            }
    }

    private var transformGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    isInteracting = true
                    liveScale = value
                }
                .onEnded { value in
                    let newScale = (placement.scale * Double(value)).clamped(to: 0.4...3.0)
                    let newRotation = placement.rotation + liveRotation.radians
                    onTransform(newScale, newRotation)
                    liveScale = 1
                    isInteracting = false
                },
            RotationGesture()
                .onChanged { value in
                    isInteracting = true
                    liveRotation = value
                }
                .onEnded { value in
                    let newRotation = placement.rotation + value.radians
                    let newScale = (placement.scale * Double(liveScale)).clamped(to: 0.4...3.0)
                    onTransform(newScale, newRotation)
                    liveRotation = .zero
                    isInteracting = false
                }
        )
    }
}
