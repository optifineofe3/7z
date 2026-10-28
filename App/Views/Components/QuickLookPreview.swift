//
//  QuickLookPreview.swift
//  SwiftUI UIViewControllerRepresentable for QLPreviewController
//

import SwiftUI
import QuickLook

public struct QuickLookPreview: UIViewControllerRepresentable {
    public let url: URL
    public let onDismiss: (() -> Void)?

    public init(url: URL, onDismiss: (() -> Void)? = nil) {
        self.url = url
        self.onDismiss = onDismiss
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIViewController(context: Context) -> UINavigationController {
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        preview.delegate = context.coordinator
        let nav = UINavigationController(rootViewController: preview)
        return nav
    }

    public func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    public class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let parent: QuickLookPreview

        init(_ parent: QuickLookPreview) {
            self.parent = parent
        }

        public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }

        public func previewControllerDidDismiss(_ controller: QLPreviewController) {
            parent.onDismiss?()
        }
    }
}
