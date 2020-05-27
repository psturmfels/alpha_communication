//
//  Receiver.swift
//  alpha_communication
//
//  Created by Pascal Sturmfels on 5/24/20.
//  Copyright © 2020 LooseFuzz. All rights reserved.
//

import UIKit
import AVFoundation
import Accelerate
import simd

class Receiver: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let position: AVCaptureDevice.Position = AVCaptureDevice.Position.front
    let quality: AVCaptureSession.Preset = AVCaptureSession.Preset.medium
    
    var permissionGranted: Bool = false
    let captureSession: AVCaptureSession = AVCaptureSession()
    let context: CIContext = CIContext()
    var shouldPrintMeasuredFrameRate: Bool = true
    let framesPerSecond: Int32 = 30
    
    var runningAverageSum: Float = 0.0
    var runningAverageCount: Float = 0.0
    var previousTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    let detectionThreshold: Float = 0.00001
    
    var frameBuffer: Array<Float> = Array<Float>()
    var persistentCaptureDevice: AVCaptureDevice?
    
    let startSequence: String = "11111111"
    let endSequence:   String = "10000000"
    var currentBitSequenceBuffer: String = ""
    var currentReceivedMessage: String = ""
    var isReceivingMessage: Bool = false
    
    var expectedMessage: String?
    
    override init() {
        super.init()
    }
    
    func stopReceiver() {
        self.captureSession.stopRunning()
    }
    
    func startReceiver(withExpectedMessage expectedMessage: String? = nil) {
        self.expectedMessage = expectedMessage
        print("Initializing receiver object.")
        self.checkPermission()
        
        DispatchQueue(label: "session_start").async {
            self.configureSession()
            self.captureSession.startRunning()
            print("Capture has started.")
            self.previousTime = CFAbsoluteTimeGetCurrent()
        }
    }
    
    // MARK: AVSession configuration
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            self.permissionGranted = true
        case .notDetermined:
            self.requestPermission()
        default:
            self.permissionGranted = false
        }
    }
    
    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
            self.permissionGranted = granted
        }
    }
    
    private func configureSession() {
        guard self.permissionGranted else { return }
        
        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        self.persistentCaptureDevice = captureDevice
        
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        print(captureDeviceInput)
        guard captureSession.canAddInput(captureDeviceInput) else { return }
        
        self.captureSession.sessionPreset = self.quality
        captureSession.addInput(captureDeviceInput)
        
        let videoOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = false
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)
        
        for vFormat in captureDevice.formats {
            let ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
            let frameRates = ranges[0]
            if frameRates.maxFrameRate == 60 && frameRates.minFrameRate == 3 {
                do {
                  try captureDevice.lockForConfiguration()
                } catch {}
                
                //Turns off auto adjusting exposure mode
                captureDevice.setExposureModeCustom(duration: CMTimeMake(value: 6934000, timescale: 1000000000), iso: 23.0, completionHandler: nil)
                captureDevice.activeFormat = vFormat as AVCaptureDevice.Format
                print(ranges)
                captureDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: framesPerSecond)
                captureDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: framesPerSecond)
                captureDevice.unlockForConfiguration()
                break
          }
        }
    }
    
    // MARK: Sample buffer to UIImage conversion
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> CIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        return ciImage
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let currentTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        let elapsed: CFAbsoluteTime = currentTime - self.previousTime
        self.runningAverageSum += Float(elapsed)
        self.runningAverageCount += 1.0
        
        if self.runningAverageCount >= 100 && self.shouldPrintMeasuredFrameRate {
            print("Average time between frames: \(self.runningAverageSum / self.runningAverageCount)")
            self.shouldPrintMeasuredFrameRate = false
        }
        self.previousTime = CFAbsoluteTimeGetCurrent()
        
        guard let capturedCiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        
        var bitmap: [UInt8] = [UInt8](repeating: 0, count: 4)
        let extent: CGRect = capturedCiImage.extent
        let inputExtent: CIVector = CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height)
        let filter: CIFilter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: capturedCiImage, kCIInputExtentKey: inputExtent])!
        let outputImage: CIImage = filter.outputImage!
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: CIFormat.RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        
        let averageRed: CGFloat = CGFloat(bitmap[0]) / 255.0
        let averageGreen: CGFloat = CGFloat(bitmap[1]) / 255.0
        let averageBlue: CGFloat = CGFloat(bitmap[2]) / 255.0
        let averageIntensity: Float = Float((averageRed + averageGreen + averageBlue) / 3.0)
        
        if self.frameBuffer.count == 6 {
            self.frameBuffer[0...4] = self.frameBuffer[1...5]
            self.frameBuffer[5] = averageIntensity
        } else {
            self.frameBuffer.append(averageIntensity)
        }
        
        if self.frameBuffer.count == 6 {
            guard let candidateBit: Int = self.determineCandidateBit(onBuffer: self.frameBuffer) else {
                return
            }
            self.frameBuffer = Array<Float>()
            
            self.currentBitSequenceBuffer.append(String(candidateBit))
            if self.currentBitSequenceBuffer.count > 8 {
                let startIndex: String.Index = self.currentBitSequenceBuffer.index(after: self.currentBitSequenceBuffer.startIndex)
                let range: Range = startIndex..<self.currentBitSequenceBuffer.endIndex
                self.currentBitSequenceBuffer = String(self.currentBitSequenceBuffer[range])
            }
            
            let distToStartSequence: Int = hammingDistance(x: self.currentBitSequenceBuffer, y: self.startSequence)
            let distToEndSequence:   Int = hammingDistance(x: self.currentBitSequenceBuffer, y: self.endSequence)
            
            if !self.isReceivingMessage && distToStartSequence <= 1 {
                self.isReceivingMessage = true
                print("Started receiving message")
            } else if self.isReceivingMessage && distToEndSequence <= 1 {
                self.isReceivingMessage = false
                
                let startIndex: String.Index = self.currentReceivedMessage.startIndex
                let endIndex: String.Index = self.currentReceivedMessage.index(self.currentReceivedMessage.endIndex, offsetBy: -7)
                let range: Range = startIndex..<endIndex
                self.currentReceivedMessage = String(self.currentReceivedMessage[range])
                print("\nReceived message: \(self.currentReceivedMessage)")
                
                if let expectedMessage = self.expectedMessage {
                    let numberOfErrors: Int = hammingDistance(x: expectedMessage, y: self.currentReceivedMessage)
                    let bitErrorRate: Float = Float(numberOfErrors) / Float(expectedMessage.count)
                    
                    let bitsPerFrame: Float = 1.0 / 6.0
                    let dataRate: Float = (1.0 - bitErrorRate) * bitsPerFrame *  Float(framesPerSecond)
                    
                    print("Bit error rate: \(bitErrorRate)")
                    print("Data rate: \(dataRate) correct bits per second")
                }
                self.currentBitSequenceBuffer = ""
            } else if self.isReceivingMessage {
                self.currentReceivedMessage.append(String(candidateBit))
                print(candidateBit, terminator: "")
            }
//
            if self.isReceivingMessage && self.currentBitSequenceBuffer.count == 8 {
                self.currentBitSequenceBuffer = ""
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Dropped frames")
    }
    
    // This function does a "pseudo" FFT
    // simply by checking if the peaks match the expected pattern
    func determineCandidateBit(onBuffer buffer: Array<Float>) -> Int? {
        let maximumOffZero: Float = [buffer[0], buffer[2], buffer[4]].max()!
        let minimumOnZero: Float  = [buffer[1], buffer[3], buffer[5]].min()!
        let meanOnZero: Float = (buffer[1] + buffer[3]) * 0.5
        
        let maximumOffOne: Float = [buffer[0], buffer[1], buffer[3], buffer[4]].max()!
        let minimumOnOne:  Float = [buffer[2], buffer[5]].min()!
        let meanOnOne: Float = buffer[2]
        
        if self.isReceivingMessage {
            if meanOnZero > meanOnOne {
                return 0
            } else {
                return 1
            }
        } else {
            if minimumOnZero > maximumOffZero + self.detectionThreshold {
                return 0
            }
            else if minimumOnOne > maximumOffOne + self.detectionThreshold {
                return 1
            } else {
                return nil
            }
        }
    }
}
