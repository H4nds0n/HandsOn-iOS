//
//  CameraViewModel.swift
//  handsOn
//
//  Created by Florian Kainberger on 18.10.23.
//

import Foundation
import AVFoundation

import TensorFlowLite

class CameraViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
//    public var session = AVCaptureSession()
    public let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var permissionGranted = false
    private var interpreter: Interpreter?
    
    var session: AVCaptureSession!
    var device: AVCaptureDevice?
    var input: AVCaptureDeviceInput?
    var videoOutput: AVCaptureVideoDataOutput!
    var output: AVCaptureMetadataOutput?
    var prevLayer: AVCaptureVideoPreviewLayer!

    var sampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    var outputQueue: DispatchQueue!
    
    @Published var currentLetter: String = "A"
    
    
    override init() {
        super.init()
        outputQueue = DispatchQueue(label: "camera.frame.processing.queue")
        
        setup()
        
    }
    
    private func setup() {
        setupModel()
        
       
            
        session = AVCaptureSession()
        device = AVCaptureDevice.default(for: AVMediaType.video)
        
        do{
            input = try AVCaptureDeviceInput(device: device!)
        }
        catch{
            print(error)
            return
        }
        
        if let input = input {
            if session.canAddInput(input) {
                session.addInput(input)
            }
        }
        
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            String(kCVPixelBufferPixelFormatTypeKey): NSNumber(value: kCVPixelFormatType_32BGRA)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        let queue = DispatchQueue(label: "video-frame-sampler")
        DispatchQueue.main.asyncAfter(deadline: .now()+20.0) { [self] in
            videoOutput!.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                
                if let connection = videoOutput.connection(with: .video) {
                    connection.videoRotationAngle = 90.0
                    
                    if connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                    }
                }
            }
            
//            DispatchQueue.background(completion:  {
                self.session.startRunning()
//            })
        }
        
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let image = imageFromSampleBuffer(sampleBuffer) {
            guard let context = CGContext(data: nil,
                                          width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
                print("[event] no context")
                return
            }
            
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard let imageData = context.data else { return }
            
//            print("[event] has imagedata \(imageData)")
            
            var inputData = Data()
            for row in 0 ..< 224 {
                for col in 0 ..< 224 {
                    
                    let offset = 4 * (row * context.width + col)
                        // (Ignore offset 0, the unused alpha channel)
                    let red = imageData.load(fromByteOffset: offset+1, as: UInt8.self)
                    let green = imageData.load(fromByteOffset: offset+2, as: UInt8.self)
                    let blue = imageData.load(fromByteOffset: offset+3, as: UInt8.self)
                    var normalizedRed = Float32(red) / 255.0
                    var normalizedGreen = Float32(green) / 255.0
                    var normalizedBlue = Float32(blue) / 255.0
                    
                        // Append normalized values to Data object in RGB order.
                    let elementSize = MemoryLayout.size(ofValue: normalizedRed)
                    var bytes = [UInt8](repeating: 0, count: elementSize)
                    memcpy(&bytes, &normalizedRed, elementSize)
                    inputData.append(&bytes, count: elementSize)
                    memcpy(&bytes, &normalizedGreen, elementSize)
                    inputData.append(&bytes, count: elementSize)
                    memcpy(&bytes, &normalizedBlue, elementSize)
                    inputData.append(&bytes, count: elementSize)
                }
            }
            
//            print("[event] done with for")
            
                // Run the interpreter
            do {
                try interpreter?.allocateTensors()
                try interpreter?.copy(inputData, toInputAt: 0)
                try interpreter?.invoke()
            } catch {
                print("[event] Error running the interpreter: \(error)")
                return
            }
            
                // Retrieve the model's output
            do {
                //interpreter is nil?
                if let output = try interpreter?.output(at: 0) {
                    print("[event] has output")
                    let probabilities = UnsafeMutableBufferPointer<Float32>.allocate(capacity: 1000)
                    output.data.copyBytes(to: probabilities)
                    
                    guard let labelPath = Bundle.main.path(forResource: "labels", ofType: "txt"),
                          let fileContents = try? String(contentsOfFile: labelPath) else {
                        return
                    }
                    let labels = fileContents.components(separatedBy: "\n")
                    
                    print("[event] has labels \(labels)")
                    
                    var highest: (class: String, confidence: Float32) = (class: "A", confidence: 0)
                    for i in labels.indices {
                        print("\(labels[i]): \(probabilities[i])")
                        if highest.confidence < probabilities[i] {
                            highest = (labels[i], probabilities[i])
                        }
                    }
                    print("[predict] predicted \(highest.class): \(highest.confidence)")
                    
                    DispatchQueue.main.async {
                        self.currentLetter = highest.class
                    }
                    
                    
                    
                    print("[event] done with all")
                } else {
                    print("[event] [no] no output \(interpreter?.outputTensorCount) \(interpreter)")
                }
            } catch {
                print("[event] [error] \(error)")
            }
        }
    }
    
    
    private func setupModel() {
        do {
            guard let modelPath =  Bundle.main.path(forResource: "asl_model", ofType: "tflite") else {
                print("[debug] model is null")
                return}
            interpreter = try Interpreter(modelPath: modelPath)
            print("[event] setup done \(interpreter)")
        }catch {
            print("error while setting up \(error)")
        }
    }
    
    
    
    private func setupCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back), let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice), session.canAddInput(videoDeviceInput) else {
            print("F")
            return
        }
        session.addInput(videoDeviceInput)
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self.sampleBufferDelegate, queue: outputQueue)
        session.addOutput(output)
        
        session.startRunning()
        
    }
    
    private func requestPermissions() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
        let context = CGContext(data: baseAddress,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo.rawValue)
        
        let image = context?.makeImage()
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        return image
    }
}

//extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
//    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        print("capture output")
//            // Convert the sample buffer to a CGImage
//        if let image = imageFromSampleBuffer(sampleBuffer) {
//                //            convertImage(image: image)
//            
//            guard let context = CGContext(data: nil,
//                                          width: image.width, height: image.height,
//                                          bitsPerComponent: 8, bytesPerRow: image.width * 4,
//                                          space: CGColorSpaceCreateDeviceRGB(),
//                                          bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
//                print("no context")
//                return
//            }
//            
//            context.draw(image, in: CGRect(x: 0, y: 0, width: 300, height: 300))
//            guard let imageData = context.data else { return }
//            
//            var inputData = Data()
//            for row in 0 ..< 300 {
//                for col in 0 ..< 300 {
//                    let offset = 4 * (row * image.width + col)
//                    let red = UInt8(imageData.load(fromByteOffset: offset+1, as: UInt8.self)) / 255
//                        //                    let red = Float32(imageData.load(fromByteOffset: offset+1, as: UInt8.self)) / 255.0
//                    let green = UInt8(imageData.load(fromByteOffset: offset+2, as: UInt8.self)) / 255
//                    let blue = UInt8(imageData.load(fromByteOffset: offset+3, as: UInt8.self)) / 255
//                    
//                    inputData.append(contentsOf: [red, green, blue])
//                }
//            }
//            
//                // Run the interpreter
//            do {
//                try interpreter?.allocateTensors()
//                try interpreter?.copy(inputData, toInputAt: 0)
//                try interpreter?.invoke()
//            } catch {
//                print("Error running the interpreter: \(error)")
//                return
//            }
//            
//                // Retrieve the model's output
//            if let output = try? interpreter?.output(at: 0) {
//                let probabilities = UnsafeMutableBufferPointer<Float32>.allocate(capacity: 1000)
//                output.data.copyBytes(to: probabilities)
//                
//                guard let labelPath = Bundle.main.path(forResource: "labels", ofType: "txt"),
//                      let fileContents = try? String(contentsOfFile: labelPath) else {
//                    return
//                }
//                let labels = fileContents.components(separatedBy: "\n")
//                
//                for i in labels.indices {
//                    print("\(labels[i]): \(probabilities[i])")
//                }
//            }
//        }
//    }
//    
//    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> CGImage? {
//        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
//            return nil
//        }
//        
//        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
//        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
//        let width = CVPixelBufferGetWidth(pixelBuffer)
//        let height = CVPixelBufferGetHeight(pixelBuffer)
//        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
//        
//        let colorSpace = CGColorSpaceCreateDeviceRGB()
//        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
//        let context = CGContext(data: baseAddress,
//                                width: width,
//                                height: height,
//                                bitsPerComponent: 8,
//                                bytesPerRow: bytesPerRow,
//                                space: colorSpace,
//                                bitmapInfo: bitmapInfo.rawValue)
//        
//        let image = context?.makeImage()
//        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
//        
//        return image
//    }
//    
//}
