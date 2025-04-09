//
//  CCharUtils.swift
//  FruitXR
//
//  Created by user on 2025/03/13.
//

import Foundation

func setToCString<T, V>(_ obj: UnsafeMutablePointer<T>, key: WritableKeyPath<T, V>, _ value: String) {
    let p = obj.pointer(to: key)
    value.withCString { bytes in
        _ = strcpy(p, bytes)
    }
}
