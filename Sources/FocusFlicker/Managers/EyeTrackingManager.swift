import AVFoundation
import Vision
import Combine
import SwiftUI

/// Manages eye tracking using Vision Framework and the front camera
class EyeTrackingManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isTracking: Bool = false
    @Published var currentMetrics: EyeMetrics = .zero
    @Published var errorMessage: String?
    @Published var cameraPermissionGranted: Bool = false
    
    // MARK: - Private Properties
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "com.focusflicker.camera")
    private let processingQueue = DispatchQueue(label: "com.focusflicker.vision")
    
    // Blink detection state - accessed only on main thread via DispatchQueue.main
    private var blinkHistory: [Date] = []
    private var lastEyeOpenness: Double = 1.0
    private var eyeClosedStartTime: Date?
    private var lastBlinkTime: Date = Date()
    private var stareStartTime: Date = Date()
    
    // Eye aspect ratio threshold for blink detection
    private let blinkThreshold: Double = 0.2
    private let blinkCooldown: TimeInterval = 0.15  // Minimum time between blinks
    
    // Rolling window for blink rate calculation
    private let blinkWindowDuration: TimeInterval = 60  // 1 minute window
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Request camera permission
    @MainActor
    func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionGranted = true
            return true
            
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermissionGranted = granted
            return granted
            
        case .denied, .restricted:
            cameraPermissionGranted = false
            errorMessage = "Camera access is required for eye tracking. Please enable it in Settings."
            return false
            
        @unknown default:
            return false
        }
    }
    
    /// Start eye tracking
    @MainActor
    func startTracking() {
        guard cameraPermissionGranted else {
            errorMessage = "Camera permission not granted"
            return
        }
        
        sessionQueue.async { [weak self] in
            self?.setupCaptureSession()
        }
    }
    
    /// Stop eye tracking
    @MainActor
    func stopTracking() {
        let session = captureSession
        sessionQueue.async {
            session?.stopRunning()
        }
        isTracking = false
    }
    
    // MARK: - Private Methods
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        // Get front camera (TrueDepth if available)
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Front camera not available"
            }
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: processingQueue)
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.captureSession = session
                self?.videoOutput = output
            }
            
            session.startRunning()
            
            DispatchQueue.main.async { [weak self] in
                self?.isTracking = true
                self?.stareStartTime = Date()
            }
            
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Failed to setup camera: \(error.localizedDescription)"
            }
        }
    }
    
    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Vision error: \(error.localizedDescription)"
                }
                return
            }
            
            guard let observations = request.results as? [VNFaceObservation],
                  let face = observations.first,
                  let landmarks = face.landmarks else {
                return
            }
            
            self.analyzeFaceLandmarks(landmarks, faceRect: face.boundingBox)
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored)
        
        do {
            try handler.perform([request])
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Failed to process frame: \(error.localizedDescription)"
            }
        }
    }
    
    private func analyzeFaceLandmarks(_ landmarks: VNFaceLandmarks2D, faceRect: CGRect) {
        // Get eye landmarks
        guard let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else {
            return
        }
        
        // Calculate eye aspect ratio (EAR) for blink detection
        let leftEAR = calculateEyeAspectRatio(leftEye)
        let rightEAR = calculateEyeAspectRatio(rightEye)
        let averageEAR = (leftEAR + rightEAR) / 2.0
        
        // Detect blinks
        let isClosed = averageEAR < blinkThreshold
        
        DispatchQueue.main.async { [weak self] in
            self?.detectBlink(isClosed: isClosed, eyeOpenness: averageEAR)
            self?.updateMetrics(eyeOpenness: averageEAR, faceRect: faceRect)
        }
    }
    
    /// Calculate Eye Aspect Ratio (EAR) for blink detection
    /// EAR = (|p2-p6| + |p3-p5|) / (2 * |p1-p4|)
    private func calculateEyeAspectRatio(_ eyeRegion: VNFaceLandmarkRegion2D) -> Double {
        let points = eyeRegion.normalizedPoints
        
        guard points.count >= 6 else { return 1.0 }
        
        // Simplified EAR using key points
        // Points are typically: corner, top1, top2, corner, bottom2, bottom1
        let p1 = points[0]  // Left corner
        let p2 = points[1]  // Top left
        let p3 = points[2]  // Top right
        let p4 = points[3]  // Right corner
        let p5 = points[4]  // Bottom right
        let p6 = points.count > 5 ? points[5] : points[4]  // Bottom left
        
        // Vertical distances
        let v1 = distance(from: p2, to: p6)
        let v2 = distance(from: p3, to: p5)
        
        // Horizontal distance
        let h = distance(from: p1, to: p4)
        
        guard h > 0 else { return 1.0 }
        
        let ear = (v1 + v2) / (2.0 * h)
        return ear
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> Double {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func detectBlink(isClosed: Bool, eyeOpenness: Double) {
        let now = Date()
        
        if isClosed && lastEyeOpenness >= blinkThreshold {
            // Eye just closed
            eyeClosedStartTime = now
        } else if !isClosed && lastEyeOpenness < blinkThreshold {
            // Eye just opened - potential blink
            if let closedStart = eyeClosedStartTime {
                let closedDuration = now.timeIntervalSince(closedStart)
                
                // Valid blink: 50-400ms closure, and not too soon after last blink
                if closedDuration >= 0.05 && closedDuration <= 0.4 {
                    let timeSinceLastBlink = now.timeIntervalSince(lastBlinkTime)
                    
                    if timeSinceLastBlink >= blinkCooldown {
                        blinkHistory.append(now)
                        lastBlinkTime = now
                        stareStartTime = now  // Reset stare timer on blink
                    }
                }
            }
            eyeClosedStartTime = nil
        }
        
        lastEyeOpenness = eyeOpenness
        
        // Clean up old blink history
        blinkHistory = blinkHistory.filter { now.timeIntervalSince($0) <= blinkWindowDuration }
    }
    
    private func updateMetrics(eyeOpenness: Double, faceRect: CGRect) {
        let now = Date()
        
        // Calculate blink rate (blinks per minute)
        let blinkRate = Double(blinkHistory.count)  // Already in 1-minute window
        
        // Estimate distance from screen using face size
        // Larger face rect = closer to screen
        let estimatedDistance = estimateDistance(from: faceRect)
        
        // Calculate continuous stare time
        let stareTime = now.timeIntervalSince(stareStartTime)
        
        currentMetrics = EyeMetrics(
            blinkRate: blinkRate,
            eyeOpenness: min(1.0, eyeOpenness / 0.3),  // Normalize to 0-1 range
            lastBlinkTime: lastBlinkTime,
            continuousStareTime: stareTime,
            estimatedDistance: estimatedDistance
        )
    }
    
    /// Estimate distance from screen based on face bounding box size
    /// Returns distance in approximate centimeters
    private func estimateDistance(from faceRect: CGRect) -> Double {
        // Average face width is ~15cm
        // When face fills 30% of frame width, user is roughly 30cm away
        // This is a rough approximation
        
        let faceWidthRatio = faceRect.width
        
        guard faceWidthRatio > 0.05 else { return 100 }  // Face too small
        
        // Inverse relationship: smaller face = farther away
        let estimatedDistance = 15.0 / faceWidthRatio
        
        return min(max(estimatedDistance, 10), 100)  // Clamp to 10-100cm
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension EyeTrackingManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        processFrame(sampleBuffer)
    }
}
