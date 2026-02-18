//
//  IPCStructs+Xr.swift
//  FruitXR
//
//  Created by user on 2026/02/18.
//

extension XrPosef {
    mutating func set(from transform: IPCTransform) {
        self.position.set(from: transform.position)
        self.orientation.set(from: transform.orientation)
    }
}

extension XrVector3f {
    mutating func set(from position: IPCPosition) {
        self.x = position.x
        self.y = position.y
        self.z = position.z
    }
}

extension XrQuaternionf {
    mutating func set(from orientation: IPCOrientation) {
        self.x = orientation.x
        self.y = orientation.y
        self.z = orientation.z
        self.w = orientation.w
    }
}
