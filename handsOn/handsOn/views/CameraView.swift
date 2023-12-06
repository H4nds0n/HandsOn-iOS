//
//  CameraView.swift
//  handsOn
//
//  Created by Florian Kainberger on 18.10.23.
//

import SwiftUI
import UIKit
import AVFoundation

struct CameraView: UIViewRepresentable {
    @ObservedObject var viewModel: CameraViewModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        let screenRect: CGRect? = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        let previewLayer = AVCaptureVideoPreviewLayer(session: viewModel.session)
        previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect!.size.width, height: screenRect!.size.height/1.5)
        previewLayer.videoGravity = .resizeAspectFill
        
        previewLayer.connection?.videoRotationAngle = 90.0
        
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.background(background: {
            viewModel.session.startRunning()
            
            print("started capture session")
        })
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
    
    
}
