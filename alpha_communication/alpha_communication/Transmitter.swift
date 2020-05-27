//
//  Transmitter.swift
//  alpha_communication
//
//  Created by Pascal Sturmfels on 5/23/20.
//  Copyright © 2020 LooseFuzz. All rights reserved.
//

import UIKit

class Transmitter: NSObject {
    var alphaOverlay: UIView?
    var flickerFrequency: Float = 1.0 / 30.0
    let alphaLow: Float = 0.01
    let alphaHigh: Float = 0.0
    
    var currentIndex: Int = 0
    var maxIndex: Int = 1
    var currentMessage: Array<Float>?
    
    let startSequence: String = "11111111"
    let endSequence:   String = "10000000"
    
    init(parentViewController: ViewController) {
        self.alphaOverlay = UIView(frame: parentViewController.view.frame)
        self.alphaOverlay!.backgroundColor = UIColor.black
        self.alphaOverlay!.alpha = CGFloat(alphaHigh)
        parentViewController.view.addSubview(self.alphaOverlay!)
    }
    
    func convertMessageToAlphaValues(message: String) -> Array<Float> {
        var convertedMessage: Array<Float> = Array<Float>()
        
        for character in message {
            if character == "0" {
                convertedMessage.append(contentsOf: [alphaLow, alphaHigh, alphaLow, alphaHigh, alphaLow, alphaHigh])
            } else if character == "1" {
                convertedMessage.append(contentsOf: [alphaLow, alphaLow, alphaHigh, alphaLow, alphaLow, alphaHigh])
            } else {
                print("Character \(character) not supported!")
            }
        }
        return convertedMessage
    }
    
    func startTransmission(withMessage message: String, withParent parent: ViewController) {
        let paddedMessage: String = self.startSequence + message + self.endSequence
        let convertedMessage: Array<Float> = self.convertMessageToAlphaValues(message: paddedMessage)
        print("Starting transmission of \(paddedMessage)")
        
        self.currentIndex = 0
        self.maxIndex = convertedMessage.count
        let startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        
        Timer.scheduledTimer(withTimeInterval: TimeInterval(flickerFrequency), repeats: true) { [unowned self] (timer) in
            self.alphaOverlay!.alpha = CGFloat(convertedMessage[self.currentIndex])
            self.currentIndex += 1
            
            if self.currentIndex == self.maxIndex {
                timer.invalidate()
                let endTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
                let duration: CFAbsoluteTime = endTime - startTime
                let expectedDuration: Float = Float(convertedMessage.count) * self.flickerFrequency
                self.alphaOverlay!.alpha = CGFloat(self.alphaHigh)
                parent.finishedTransmission()
                print("Finished transmission of \(message). Time taken: \(duration). Expected time: \(expectedDuration).")
            }
        }
    }
}
