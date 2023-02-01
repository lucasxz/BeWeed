//
//  ViewController.swift
//  BeWeed
//
//  Created by Lucas Zhou on 1/31/23.
//

import UIKit
import SwiftUI
import AVFoundation
import Vision
import CoreHaptics

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var permissionGranted = false // Flag for permission

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)

    private var previewLayer = AVCaptureVideoPreviewLayer()
    var screenRect: CGRect! = nil // For view dimensions
    
    private var requests = [VNRequest]()
    
    private var foundTime: Date? = nil
    private var pic = false
    
    // Haptic stuff
    
    // A haptic engine manages the connection to the haptic server.
    var engine: CHHapticEngine?
    
    // Maintain a variable to check for Core Haptics compatibility on device.
    
    override func viewDidLoad() {
        checkPermission()
        
        print("testing logs")
        
        playHapticsFile(named: "AHAP/Boing")
        
        sessionQueue.async { [unowned self] in
            guard permissionGranted else { return }
            self.setupCaptureSession()
            self.captureSession.startRunning()
        }
        
        createEngine()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation: CGImagePropertyOrientation = .up
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        let request = VNClassifyImageRequest()
        try? imageRequestHandler.perform([request])
        
        let lookingFor = ["pen", "tool"]
        let filtered = request.results?.filter({lookingFor.contains($0.identifier) && $0.confidence > 0.1})
        
        //if filtered?.count ?? 0 > 0 { print(filtered?[0] ?? "?") }
        
        if (filtered!.count > 0) {
            if (self.foundTime == nil) {
                self.foundTime = Date()
            } else if ((self.foundTime?.distance(to: Date()))! > 3) {
                print("taking picture!")
                playHapticsFile(named: "AHAP/Boing")
                self.foundTime = nil
            } else if ((self.foundTime?.distance(to: Date()))! > 2) {
                print("2")
            } else if ((self.foundTime?.distance(to: Date()))! > 1) {
                print("1")
            }
            
        }
        else {
            self.foundTime = nil
            print("shit")
        }
    }
    
    /// - Tag: CreateEngine
    func createEngine() {
        // Create and configure a haptic engine.
        do {
            // Associate the haptic engine with the default audio session
            // to ensure the correct behavior when playing audio-based haptics.
            let audioSession = AVAudioSession.sharedInstance()
            engine = try CHHapticEngine(audioSession: audioSession)
        } catch let error {
            print("Engine Creation Error: \(error)")
        }
        
        guard let engine = engine else {
            print("Failed to create engine!")
            return
        }
        
        // The stopped handler alerts you of engine stoppage due to external causes.
        engine.stoppedHandler = { reason in
            print("The engine stopped for reason: \(reason.rawValue)")
            switch reason {
            case .audioSessionInterrupt:
                print("Audio session interrupt")
            case .applicationSuspended:
                print("Application suspended")
            case .idleTimeout:
                print("Idle timeout")
            case .systemError:
                print("System error")
            case .notifyWhenFinished:
                print("Playback finished")
            case .gameControllerDisconnect:
                print("Controller disconnected.")
            case .engineDestroyed:
                print("Engine destroyed.")
            @unknown default:
                print("Unknown error")
            }
        }
 
        // The reset handler provides an opportunity for your app to restart the engine in case of failure.
        engine.resetHandler = {
            // Try restarting the engine.
            print("The engine reset --> Restarting now!")
            do {
                try self.engine?.start()
            } catch {
                print("Failed to restart the engine: \(error)")
            }
        }
    }
    
    /// - Tag: PlayAHAP
    func playHapticsFile(named filename: String) {
        
        print("kek")
        // Express the path to the AHAP file before attempting to load it.
        guard let path = Bundle.main.path(forResource: filename, ofType: "ahap") else {
            return
        }
        print("kekk")
        do {
            // Start the engine in case it's idle.
            try engine?.start()
            
            // Tell the engine to play a pattern.
            try engine?.playPattern(from: URL(fileURLWithPath: path))
            print("kekkk")
        
            
        } catch { // Engine startup errors
            print("An error occured playing \(filename): \(error).")
        }
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            // Permission has been granted before
            case .authorized:
                permissionGranted = true

            // Permission has not been requested yet
            case .notDetermined:
                requestPermission()
    
            default:
                permissionGranted = false
        }
    }

    func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }

    func setupCaptureSession() {
        
        captureSession.beginConfiguration()
        
        // Access camera
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,for: .video, position: .front) else { return }
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
            
        guard captureSession.canAddInput(videoDeviceInput) else { return }
        captureSession.addInput(videoDeviceInput)
        
        // Setup outputs
        let photoOutput = AVCapturePhotoOutput()
        guard captureSession.canAddOutput(photoOutput) else { return }
        captureSession.addOutput(photoOutput)

        let videoDataOutput = AVCaptureVideoDataOutput()
        guard captureSession.canAddOutput(videoDataOutput) else { return }
        captureSession.addOutput(videoDataOutput)

        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        captureSession.commitConfiguration()
                          
        screenRect = UIScreen.main.bounds

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill // Fill screen

        previewLayer.connection?.videoOrientation = .portrait
        
        // Updates to UI must be on main queue
        DispatchQueue.main.async { [weak self] in
            self!.view.layer.addSublayer(self!.previewLayer)
        }
    }
}

struct HostedViewController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return ViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
}
