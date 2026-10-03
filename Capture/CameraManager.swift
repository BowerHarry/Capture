import Foundation
import AVFoundation
import UIKit

/// Owns the capture session. All session configuration and start/stop calls run on
/// `sessionQueue`; photo results are delivered back on the main queue.
final class CameraManager: NSObject, ObservableObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    // Only touched on sessionQueue
    private var isConfigured = false
    // Only touched on the main queue
    private var captureCompletion: ((UIImage?) -> Void)?
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc private func appDidBecomeActive() {
        sessionQueue.async {
            if self.isConfigured && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    @objc private func appWillResignActive() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    func ensureSessionRunning() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) {
                startSession()
            } else {
                Log.error("[Camera] Permission denied")
            }
        default:
            break
        }
    }
    
    private func startSession() {
        sessionQueue.async {
            if !self.isConfigured {
                self.configureSession()
            }
            if self.isConfigured && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }
    
    /// Must be called on `sessionQueue`.
    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        
        for input in session.inputs { session.removeInput(input) }
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            Log.error("[Camera] Failed to create device input: \(error.localizedDescription)")
            return
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            let largest = device.activeFormat.supportedMaxPhotoDimensions.max { $0.width * $0.height < $1.width * $1.height }
            if let largest {
                photoOutput.maxPhotoDimensions = largest
            }
        }
        
        isConfigured = true
    }
    
    /// Call from the main queue. `completion` is called on the main queue.
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        captureCompletion = completion
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        var image: UIImage?
        if let error {
            Log.error("[Camera] Photo capture error: \(error.localizedDescription)")
        } else if let data = photo.fileDataRepresentation() {
            image = UIImage(data: data)
        }
        DispatchQueue.main.async {
            self.captureCompletion?(image)
            self.captureCompletion = nil
        }
    }
}
