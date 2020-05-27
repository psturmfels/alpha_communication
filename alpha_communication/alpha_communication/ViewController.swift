//
//  ViewController.swift
//  alpha_communication
//
//  Created by Pascal Sturmfels on 5/23/20.
//  Copyright © 2020 LooseFuzz. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    var transmitter: Transmitter?
    var receiver: Receiver?
    
    var transmitButton: UIButton?
    var receiveButton: UIButton?
    let message: String = String(repeating: "10101100", count: 12)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.transmitter = Transmitter(parentViewController: self)
        self.receiver = Receiver()
        
        self.setupButtons()
    }
    
    func setupButtons() {
        self.transmitButton = UIButton(type: UIButton.ButtonType.system)
        self.transmitButton!.setTitle("Transmit", for: UIControl.State.normal)
        self.transmitButton!.titleLabel!.font = UIFont.systemFont(ofSize: 48.0)
        self.transmitButton!.frame = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 100.0)
        self.transmitButton!.center = CGPoint(x: self.view.center.x, y: self.view.center.y - 50.0)
        self.transmitButton!.addTarget(self, action: #selector(startTransmission), for: UIControl.Event.touchUpInside)
        self.view.addSubview(self.transmitButton!)
        
        self.receiveButton = UIButton(type: UIButton.ButtonType.system)
        self.receiveButton!.setTitle("Receive", for: UIControl.State.normal)
        self.receiveButton!.titleLabel!.font = UIFont.systemFont(ofSize: 48.0)
        self.receiveButton!.frame = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 100.0)
        self.receiveButton!.center = CGPoint(x: self.view.center.x, y: self.view.center.y + 50.0)
        self.receiveButton!.addTarget(self, action: #selector(startReceiver), for: UIControl.Event.touchUpInside)
        self.view.addSubview(self.receiveButton!)
    }
    
    @objc func startTransmission() {
        let transmissionDelay: TimeInterval = 2.0
        self.transmitButton!.isUserInteractionEnabled = false
        self.transmitButton!.alpha = 0.0
        self.receiveButton!.isUserInteractionEnabled = false
        self.receiveButton!.alpha = 0.0
        Timer.scheduledTimer(withTimeInterval: transmissionDelay, repeats: false) { [unowned self] (timer) in
            self.transmitter!.startTransmission(withMessage: self.message, withParent: self)
        }
    }
    
    func finishedTransmission() {
        let transmissionDelay: TimeInterval = 2.0
        Timer.scheduledTimer(withTimeInterval: transmissionDelay, repeats: false) { [unowned self] (timer) in
            self.transmitButton!.isUserInteractionEnabled = true
            self.transmitButton!.alpha = 1.0
            self.receiveButton!.isUserInteractionEnabled = true
            self.receiveButton!.alpha = 1.0
        }
    }
    
    @objc func startReceiver() {
        if self.receiver!.captureSession.isRunning {
            self.receiver!.stopReceiver()
        } else {
            self.receiver!.startReceiver(withExpectedMessage: message)
        }
    }
}

