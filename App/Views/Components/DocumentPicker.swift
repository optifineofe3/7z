//
//  DocumentPicker.swift
//  SwiftUI UIViewControllerRepresentable for UIDocumentPickerViewController
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

public struct DocumentPicker: UIViewControllerRepresentable {
    public enum Mode {
        case openFile(types: [UTType], asCopy: Bool = true, onPick: (URL) -> Void)
        case openFolder(onPick: (URL) -> Void)
        case exportFile(url: URL, onComplete: () -> Void)
    }

    public let mode: Mode

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        switch mode {
        case .openFile(let types, let asCopy, _):
            picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: asCopy)
        case .openFolder(_):
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        case .exportFile(let url, _):
            picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        }
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            switch parent.mode {
            case .openFile(_, _, let onPick):
                onPick(url)
            case .openFolder(let onPick):
                onPick(url)
            case .exportFile(_, let onComplete):
                onComplete()
            }
        }
    }
}
