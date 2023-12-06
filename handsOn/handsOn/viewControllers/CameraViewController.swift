//
//  CameraViewController.swift
//  handsOn
//
//  Created by Florian Kainberger on 18.10.23.
//

import UIKit
import SwiftUI
import AVFoundation

class CameraViewController: UIViewController {
    private var permissionGranted = false
    
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    
    private var previewLayer = AVCaptureVideoPreviewLayer()
    var screenRect: CGRect? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        checkPermissions()
        
        sessionQueue.async { [unowned self] in
            guard permissionGranted else {return}
            self.setupCaptureSession()
            self.captureSession.startRunning()
        }
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                permissionGranted = true
            case .notDetermined:
                requestPermissions()
            default:
                permissionGranted = false
        }
    }
    
    private func setupCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back), let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice), captureSession.canAddInput(videoDeviceInput) else {
            print("F")
            return
        }
        
        captureSession.addInput(videoDeviceInput)
        
        screenRect = UIScreen.main.bounds
        guard screenRect != nil else {return}
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect!.size.width, height: screenRect!.size.height)
        previewLayer.videoGravity = .resizeAspectFill
        
        previewLayer.connection?.videoRotationAngle = 90.0
        DispatchQueue.main.async {
            self.view.layer.addSublayer(self.previewLayer)
        }
    }
    
    private func requestPermissions() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }

}

struct HostedCameraViewController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> some UIViewController {
        return CameraViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
}
