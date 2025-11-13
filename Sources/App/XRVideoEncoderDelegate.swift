//
//  XRVideoEncoderDelegate.swift
//  FruitXR
//
//  Created by user on 2025/11/13.
//

protocol XRVideoEncoderDelegate: AnyObject {
    func send(message: ToBrowser)
}
