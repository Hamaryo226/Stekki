//
//  ActivityShareSheet.swift
//  Stekki
//
//  UIActivityViewController のSwiftUIラッパー。.stickertrade ファイルのURLを渡して
//  AirDropやその他の共有先へ送るために使う。
//

import SwiftUI
import UIKit

struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
