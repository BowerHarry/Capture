import SwiftUI
import AVFoundation

struct CameraCaptureView: View {
    @EnvironmentObject var habitManager: HabitManager
    @StateObject private var cameraManager = CameraManager()
    
    let preselectedHabitId: String?
    let onBack: () -> Void
    
    @State private var isPublic = true
    @State private var isSaving = false
    @State private var capturedImage: UIImage?
    
    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Full-screen live camera preview
                LiveCameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()
                    .background(Color.black)
                
                // Overlays
                VStack {
                    HStack {
                        Button(action: { onBack() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    Spacer()
                    
                    // Shutter controls
                    HStack(spacing: 40) {
                        Spacer()
                        Button(action: captureAndSave) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 78, height: 78)
                                Circle()
                                    .stroke(Color.black.opacity(0.2), lineWidth: 2)
                                    .frame(width: 86, height: 86)
                            }
                        }
                        .disabled(isSaving || preselectedHabitId == nil)
                        Spacer()
                    }
                    .padding(.bottom, 36)
                }
                .ignoresSafeArea(edges: .top)
                
                if isSaving {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView("Saving...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                        .padding(20)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                }
            }
            .task { await cameraManager.ensureSessionRunning() }
        }
    }
    
    private func captureAndSave() {
        guard let habitIdString = preselectedHabitId,
              let habitId = UUID(uuidString: habitIdString) else { return }
        isSaving = true
        cameraManager.capturePhoto { image in
            Task {
                defer { isSaving = false }
                guard let image = image, let data = image.jpegData(compressionQuality: 0.85) else { return }
                await habitManager.createCapture(
                    habitId: habitId,
                    caption: nil,
                    isPublic: isPublic,
                    imageData: data
                )
                if habitManager.errorMessage == nil {
                    onBack()
                }
            }
        }
    }
}

private struct LiveCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let connection = view.videoPreviewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
        uiView.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let connection = uiView.videoPreviewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
    
    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        override func layoutSubviews() {
            super.layoutSubviews()
            videoPreviewLayer.frame = bounds
        }
    }
}

#Preview {
    CameraCaptureView(preselectedHabitId: nil, onBack: {})
        .environmentObject(HabitManager.shared)
}
