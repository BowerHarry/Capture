import Foundation
import AVFoundation
import UIKit

@MainActor
class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    let previewLayer = AVCaptureVideoPreviewLayer()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage?) -> Void)?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var isConfigured = false
    
    override init() {
        super.init()
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        addLifecycleObservers()
    }
    
    private func addLifecycleObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc private func appDidBecomeActive() {
        sessionQueue.async {
            if !self.session.isRunning && self.isConfigured {
                NSLog("[Camera] App active: starting session")
                self.session.startRunning()
            }
        }
    }
    
    @objc private func appWillResignActive() {
        sessionQueue.async {
            if self.session.isRunning {
                NSLog("[Camera] App inactive: stopping session")
                self.session.stopRunning()
            }
        }
    }
    
    func ensureSessionRunning() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            setupCameraIfNeeded()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { setupCameraIfNeeded() }
            else { NSLog("[Camera] Permission denied") }
        default:
            NSLog("[Camera] Permission not authorized: %@", String(describing: status))
        }
    }
    
    private func setupCameraIfNeeded() {
        if isConfigured {
            sessionQueue.async {
                if !self.session.isRunning {
                    NSLog("[Camera] Already configured; starting session")
                    self.session.startRunning()
                }
            }
            return
        }
        setupCamera()
    }
    
    private func setupCamera() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            // Clean inputs
            for input in self.session.inputs { self.session.removeInput(input) }
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                NSLog("[Camera] No back camera device available")
                self.session.commitConfiguration()
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    NSLog("[Camera] Cannot add camera input")
                }
            } catch {
                NSLog("[Camera] Failed to create device input: %@", error.localizedDescription)
            }
            
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.isHighResolutionCaptureEnabled = true
            } else {
                NSLog("[Camera] Cannot add photo output")
            }
            
            self.session.commitConfiguration()
            self.isConfigured = true
            if !self.session.isRunning {
                NSLog("[Camera] Starting session")
                self.session.startRunning()
            }
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func switchCamera() {
        // Implementation for switching between front and back camera
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            NSLog("[Camera] Photo capture error: %@", error.localizedDescription)
            captureCompletion?(nil)
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            NSLog("[Camera] No image data from capture")
            captureCompletion?(nil)
            return
        }
        captureCompletion?(image)
    }
}