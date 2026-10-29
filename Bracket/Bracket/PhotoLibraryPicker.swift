import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onLoading: () -> Void
    let onSelection: (Result<CapturedPhoto?, Error>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLoading: onLoading, onSelection: onSelection) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onLoading: () -> Void
        let onSelection: (Result<CapturedPhoto?, Error>) -> Void

        init(onLoading: @escaping () -> Void, onSelection: @escaping (Result<CapturedPhoto?, Error>) -> Void) {
            self.onLoading = onLoading
            self.onSelection = onSelection
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else { onSelection(.success(nil)); return }
            guard let identifier = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true }) else {
                onSelection(.failure(LibraryError.unreadablePhoto))
                return
            }
            onLoading()
            provider.loadDataRepresentation(forTypeIdentifier: identifier) { data, error in
                let result: Result<CapturedPhoto?, Error>
                if let error { result = .failure(error) }
                else if let data, let photo = CapturedPhoto(data: data) { result = .success(photo) }
                else { result = .failure(LibraryError.unreadablePhoto) }
                DispatchQueue.main.async { self.onSelection(result) }
            }
        }
    }

    private enum LibraryError: LocalizedError {
        case unreadablePhoto
        var errorDescription: String? { "This photo could not be opened. Please choose another photo." }
    }
}
