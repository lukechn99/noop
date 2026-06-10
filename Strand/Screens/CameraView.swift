#if os(iOS)
import SwiftUI
import AVFoundation
import Photos
import StrandDesign

// MARK: - Camera session model

@MainActor
final class CameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "noop.camera.session")
    @Published var lastThumbnail: UIImage?

    override init() {
        super.init()
        sessionQueue.async { [weak self] in self?.configure() }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { session.commitConfiguration(); return }
        session.addInput(input)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        session.startRunning()
    }

    func start() {
        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func capturePhoto(onSaved: @escaping () -> Void) {
        let settings = AVCapturePhotoSettings()
        let delegate = CaptureDelegate(onSaved: onSaved) { [weak self] img in
            Task { @MainActor [weak self] in self?.lastThumbnail = img }
        }
        output.capturePhoto(with: settings, delegate: delegate)
        // Hold a strong reference until the delegate callback fires.
        capturePool.append(delegate)
    }

    private var capturePool: [CaptureDelegate] = []

    func releaseDone(_ delegate: CaptureDelegate) {
        capturePool.removeAll { $0 === delegate }
    }
}

// MARK: - Per-capture delegate (held alive by capturePool)

final class CaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let onSaved: () -> Void
    private let onImage: (UIImage?) -> Void

    init(onSaved: @escaping () -> Void, onImage: @escaping (UIImage?) -> Void) {
        self.onSaved = onSaved
        self.onImage = onImage
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else {
            onImage(nil); return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCreationRequest.forAsset()
                req.addResource(with: .photo, data: data, options: nil)
            }
        }
        onImage(UIImage(data: data))
        onSaved()
    }
}

// MARK: - Live preview (UIKit layer bridged to SwiftUI)

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView { PreviewView(session: session) }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        init(session: AVCaptureSession) {
            super.init(frame: .zero)
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
        }
        required init?(coder: NSCoder) { fatalError() }
    }
}

// MARK: - Camera view

struct CameraView: View {
    @StateObject private var camera = CameraModel()
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFlash = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            // Brief white flash on capture
            if showFlash {
                Color.white.ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            VStack {
                // Top bar
                HStack {
                    Button {
                        camera.stop()
                        model.showCamera = false
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    Spacer()
                    Text("NOOP Camera")
                        .font(StrandFont.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    // Balance the X button
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                // Shutter row
                HStack {
                    // Last thumbnail
                    if let thumb = camera.lastThumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white.opacity(0.15))
                            .frame(width: 52, height: 52)
                    }
                    Spacer()
                    // Shutter button
                    Button { takePhoto() } label: {
                        ZStack {
                            Circle().fill(.white).frame(width: 72, height: 72)
                            Circle().stroke(.white.opacity(0.4), lineWidth: 3).frame(width: 84, height: 84)
                        }
                    }
                    Spacer()
                    // Double-tap hint
                    VStack(spacing: 3) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("Tap strap\nto shoot")
                            .font(.system(size: 10))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(width: 52)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
        .onAppear { camera.start() }
        .onDisappear {
            camera.stop()
            model.showCamera = false
        }
        // Double-tap from strap fires shutter
        .onChange(of: model.cameraTrigger) { _ in takePhoto() }
    }

    private func takePhoto() {
        camera.capturePhoto {
            model.buzz(loops: 1)
        }
        withAnimation(.easeOut(duration: 0.08)) { showFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeIn(duration: 0.15)) { showFlash = false }
        }
    }
}
#endif
