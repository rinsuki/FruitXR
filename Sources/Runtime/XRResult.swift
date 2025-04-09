//
//  XRResult.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

enum XRResult<T> {
    case success(T)
    case failure(XrResult)
}
