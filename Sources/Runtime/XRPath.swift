//
//  XRPath.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

nonisolated(unsafe) var xrRegisteredPaths: [String] = [
    "", // XR_NULL_PATH
    "/user/hand/left",
    "/user/hand/right",
    "/interaction_profiles/oculus/touch_controller",
]

let XR_PATH_USER_HAND_LEFT: XrPath = 1
let XR_PATH_USER_HAND_RIGHT: XrPath = 2
let XR_PATH_OCULUS_TOUCH_CONTROLLER: XrPath = 3

func xrStringToPath(instance: XrInstance?, pathString: UnsafePointer<CChar>?, pathPtr: UnsafeMutablePointer<XrPath>?) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    
    guard let pathString else {
        return XR_ERROR_PATH_INVALID
    }
    let path = String(cString: pathString)
    
    if let currentPath = xrRegisteredPaths.firstIndex(of: path) {
        pathPtr!.pointee = .init(currentPath)
        return XR_SUCCESS
    }

    xrRegisteredPaths.append(path)
    pathPtr!.pointee = .init(xrRegisteredPaths.count - 1)
    
    return XR_SUCCESS
}

func xrPathToString(instance: XrInstance?, path: XrPath, bufferCapacityInput: UInt32, bufferCountOutput: UnsafeMutablePointer<UInt32>?, buffer: UnsafeMutablePointer<CChar>?) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    
    guard path < xrRegisteredPaths.count else {
        return XR_ERROR_PATH_INVALID
    }
    
    let pathString = xrRegisteredPaths[Int(path)]
    
    print("STUB: xrPathToString(\(instanceObj), \(path), \(bufferCapacityInput))")
    
    let requiredLength = pathString.utf8.count + 1
    bufferCountOutput!.pointee = .init(requiredLength)
    guard bufferCapacityInput >= requiredLength else {
        return XR_ERROR_SIZE_INSUFFICIENT
    }
    
    guard let buffer else {
        preconditionFailure()
    }
    
    let utf8 = pathString.utf8CString
    let length = utf8.count
    _ = utf8.withUnsafeBytes { utf8 in
        memcpy(buffer, utf8.baseAddress, min(Int(bufferCapacityInput), length))
    }
    
    return XR_SUCCESS
}
