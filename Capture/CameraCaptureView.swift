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
    @State private var showingImagePicker = false
    @State private var showingCapturedImage = false
    
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
                        
                        // Photo library button
                        Button(action: {
                            showingImagePicker = true
                        }) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    Spacer()
                    
                    // Shutter controls
                    HStack(spacing: 40) {
                        Spacer()
                        Button(action: capturePhoto) {
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
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerCropper(selectedImage: $capturedImage)
            }
            .onChange(of: capturedImage) { image in
                if let image = image {
                    showingCapturedImage = true
                }
            }
            .sheet(isPresented: $showingCapturedImage) {
                if let image = capturedImage {
                    CapturedImageView(
                        image: image,
                        isPublic: $isPublic,
                        onSave: {
                            Task {
                                await saveImage(image)
                            }
                        },
                        onRetake: {
                            capturedImage = nil
                            showingCapturedImage = false
                        }
                    )
                }
            }
        }
    }
    
    private func capturePhoto() {
        guard let habitIdString = preselectedHabitId,
              let habitId = UUID(uuidString: habitIdString) else { return }
        
        cameraManager.capturePhoto { image in
            if let image = image {
                capturedImage = image
                showingCapturedImage = true
            }
        }
    }
    
    private func saveImage(_ image: UIImage) async {
        guard let habitIdString = preselectedHabitId,
              let habitId = UUID(uuidString: habitIdString),
              let data = image.jpegData(compressionQuality: 0.85) else { return }
        
        isSaving = true
        defer { isSaving = false }
        
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

// MARK: - Captured Image View

struct CapturedImageView: View {
    let image: UIImage
    @Binding var isPublic: Bool
    let onSave: () -> Void
    let onRetake: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingCropper = false
    @State private var croppedImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Image preview
                Image(uiImage: croppedImage ?? image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                // Public/Private toggle
                HStack {
                    Text("Make public")
                        .font(.headline)
                    
                    Spacer()
                    
                    Toggle("", isOn: $isPublic)
                        .labelsHidden()
                }
                .padding(.horizontal, 20)
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Retake") {
                        onRetake()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("Crop") {
                        showingCropper = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Review Photo")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCropper) {
                ImageCropperView(image: image) { cropped in
                    croppedImage = cropped
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
