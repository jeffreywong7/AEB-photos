import SwiftUI
import UIKit

struct PhotoReviewView: View {
    let capturedPhotos: [CapturedPhoto]
    @Environment(\.dismiss) private var dismiss
    @State private var selection = 0
    @State private var chromeVisible = true
    @State private var zoomed = false
    @State private var dragOffset: CGFloat = 0
    @State private var sheet: ReviewSheet?
    @State private var shareError: String?
    @State private var libraryError: String?
    @State private var libraryPhoto: CapturedPhoto?
    @State private var libraryLoading = false

    private var photos: [CapturedPhoto] { libraryPhoto.map { [$0] } ?? capturedPhotos }

    init(photos: [CapturedPhoto]) {
        self.capturedPhotos = photos
        _selection = State(initialValue: photos.count / 2)
    }

    private enum ReviewSheet: Identifiable {
        case share(URL)
        case info(CapturedPhoto)
        case library

        var id: String {
            switch self {
            case .share(let url): return url.absoluteString
            case .info(let photo): return photo.id.uuidString
            case .library: return "library"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !photos.isEmpty {
                TabView(selection: $selection) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        ZoomablePhotoView(photo: photo, selected: selection == index,
                                          onTap: { withAnimation(.easeInOut(duration: 0.18)) { chromeVisible.toggle() } },
                                          onZoom: { if selection == index { zoomed = $0 } })
                            .tag(index)
                            .accessibilityIdentifier("camera.review.image.\(index)")
                            .accessibilityLabel("Photo \(index + 1) of \(photos.count)")
                            .accessibilityValue(selection == index && zoomed ? "Zoomed" : "Fit")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .offset(y: dragOffset)
                .simultaneousGesture(DragGesture(minimumDistance: 25)
                    .onChanged { value in
                        if !zoomed, value.translation.height > 0, abs(value.translation.height) > abs(value.translation.width) {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { _ in
                        if dragOffset > 120 { dismiss() }
                        else { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { dragOffset = 0 } }
                    })
            }
            if chromeVisible {
                VStack {
                    topBar
                    Spacer()
                    bottomBar
                }
                .transition(.opacity)
            }
            if libraryLoading {
                ProgressView("Opening photo…")
                    .padding(24).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: selection) { _ in zoomed = false; dragOffset = 0 }
        .onAppear { if photos.isEmpty { sheet = .library } }
        .sheet(item: $sheet) { item in
            switch item {
            case .share(let url): CaptureShareView(fileURL: url)
            case .info(let photo):
                NavigationStack {
                    Form {
                        if let date = photo.createdAt {
                            LabeledContent("Captured") { Text(date, style: .date) }
                        } else {
                            LabeledContent("Captured", value: "Unknown")
                        }
                        LabeledContent("Dimensions", value: photo.pixelDimensions)
                        LabeledContent("Format", value: photo.formatName)
                        LabeledContent("File size", value: ByteCountFormatter.string(fromByteCount: Int64(photo.data.count), countStyle: .file))
                    }
                    .navigationTitle("Photo Info")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sheet = nil } } }
                }.presentationDetents([.medium])
            case .library:
                PhotoLibraryPicker(onLoading: { sheet = nil; libraryLoading = true }, onSelection: { result in
                    sheet = nil
                    libraryLoading = false
                    switch result {
                    case .success(let photo):
                        if let photo { libraryPhoto = photo; selection = 0; zoomed = false; dragOffset = 0 }
                        else if photos.isEmpty { dismiss() }
                    case .failure(let error): libraryError = error.localizedDescription
                    }
                }).ignoresSafeArea()
            }
        }
        .alert("Could not share photo", isPresented: Binding(get: { shareError != nil }, set: { if !$0 { shareError = nil } })) {
            Button("OK", role: .cancel) { shareError = nil }
        } message: { Text(shareError ?? "") }
        .alert("Could not open photo", isPresented: Binding(get: { libraryError != nil }, set: { if !$0 { libraryError = nil } })) {
            Button("OK", role: .cancel) { libraryError = nil }
        } message: { Text(libraryError ?? "") }
        .cameraSnapshotPreview(review: true)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Return to camera")
            .accessibilityIdentifier("camera.review.close")
            Spacer()
            if photos.indices.contains(selection) {
                if let date = photos[selection].createdAt {
                    VStack(spacing: 2) {
                        Text(date, style: .date).font(.system(size: 14, weight: .semibold))
                        Text(date, style: .time).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
                    }
                } else {
                    Text("Unknown date").font(.system(size: 14, weight: .semibold))
                }
            }
            Spacer()
            Button { sheet = .library } label: {
                Image(systemName: "photo.on.rectangle.angled").font(.system(size: 20))
                    .frame(width: 44, height: 44)
            }
            .disabled(libraryLoading)
            .accessibilityLabel("Browse photo library")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12).padding(.bottom, 10)
        .background(LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom))
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Button {
                guard photos.indices.contains(selection) else { return }
                do { sheet = .share(try photos[selection].prepareShareFile()) }
                catch { shareError = error.localizedDescription }
            } label: {
                Image(systemName: "square.and.arrow.up").font(.system(size: 20)).frame(width: 44, height: 44)
            }.accessibilityLabel("Share original photo")
                .disabled(photos.isEmpty || libraryLoading)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    Button { selection = index } label: {
                        Image(uiImage: photo.preview).resizable().scaledToFill()
                            .frame(width: 30, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(selection == index ? .white : .clear, lineWidth: 2))
                    }.accessibilityLabel("View photo \(index + 1) of \(photos.count)")
                }
            }
            Spacer(minLength: 0)
            Button {
                if photos.indices.contains(selection) { sheet = .info(photos[selection]) }
            } label: {
                Image(systemName: "info.circle").font(.system(size: 20)).frame(width: 44, height: 44)
            }.accessibilityLabel("Photo information")
                .disabled(photos.isEmpty || libraryLoading)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.top, 14)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom))
    }
}

private struct CaptureShareView: UIViewControllerRepresentable {
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> URL { fileURL }
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in dismiss() }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
    static func dismantleUIViewController(_ controller: UIActivityViewController, coordinator: URL) {
        try? FileManager.default.removeItem(at: coordinator)
    }
}

private struct ZoomablePhotoView: UIViewRepresentable {
    let photo: CapturedPhoto
    let selected: Bool
    let onTap: () -> Void
    let onZoom: (Bool) -> Void

    func makeUIView(context: Context) -> PhotoScrollView {
        let view = PhotoScrollView(image: photo.image)
        view.onTap = onTap
        view.onZoom = onZoom
        return view
    }
    func updateUIView(_ view: PhotoScrollView, context: Context) {
        view.onTap = onTap
        view.onZoom = onZoom
        if !selected { view.resetZoom() }
    }

    final class PhotoScrollView: UIScrollView, UIScrollViewDelegate {
        private let imageView: UIImageView
        private var lastSize: CGSize = .zero
        private var reportedZoom = false
        var onTap: (() -> Void)?
        var onZoom: ((Bool) -> Void)?

        init(image: UIImage) {
            imageView = UIImageView(image: image)
            super.init(frame: .zero)
            delegate = self
            showsVerticalScrollIndicator = false
            showsHorizontalScrollIndicator = false
            contentInsetAdjustmentBehavior = .never
            panGestureRecognizer.isEnabled = false
            backgroundColor = .black
            addSubview(imageView)
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(toggleZoom(_:)))
            doubleTap.numberOfTapsRequired = 2
            addGestureRecognizer(doubleTap)
            let tap = UITapGestureRecognizer(target: self, action: #selector(toggleChrome))
            tap.require(toFail: doubleTap)
            addGestureRecognizer(tap)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            if bounds.size != lastSize, bounds.width > 0, bounds.height > 0, let image = imageView.image {
                lastSize = bounds.size
                maximumZoomScale = max(maximumZoomScale, 1)
                minimumZoomScale = min(minimumZoomScale, 1)
                setZoomScale(1, animated: false)
                imageView.frame = CGRect(origin: .zero, size: image.size)
                contentSize = image.size
                let fit = min(bounds.width / image.size.width, bounds.height / image.size.height)
                maximumZoomScale = max(fit * 8, 1)
                minimumZoomScale = fit
                maximumZoomScale = fit * 8
                setZoomScale(fit, animated: false)
            }
            centerPhoto()
        }

        func resetZoom() {
            if zoomScale > minimumZoomScale { setZoomScale(minimumZoomScale, animated: false) }
        }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerPhoto()
            let zoomed = zoomScale > minimumZoomScale * 1.01
            panGestureRecognizer.isEnabled = zoomed
            if zoomed != reportedZoom { reportedZoom = zoomed; onZoom?(zoomed) }
        }
        private func centerPhoto() {
            let inset = UIEdgeInsets(top: max(0, (bounds.height - contentSize.height) / 2), left: max(0, (bounds.width - contentSize.width) / 2), bottom: 0, right: 0)
            if contentInset != inset { contentInset = inset }
        }
        @objc private func toggleChrome() { onTap?() }
        @objc private func toggleZoom(_ tap: UITapGestureRecognizer) {
            if zoomScale > minimumZoomScale * 1.01 { setZoomScale(minimumZoomScale, animated: true); return }
            let target = minimumZoomScale * 3
            let point = tap.location(in: imageView)
            let size = CGSize(width: bounds.width / target, height: bounds.height / target)
            zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true)
        }
    }
}
