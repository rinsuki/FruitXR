//
//  XRPath.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

nonisolated(unsafe) var paths: [String] = []

func xrStringToPath(instance: XrInstance?, pathString: UnsafePointer<CChar>?, pathPtr: UnsafeMutablePointer<XrPath>?) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    
    guard let pathString else {
        return XR_ERROR_PATH_INVALID
    }
    let path = String(cString: pathString)
    
    print("STUB: xrStringToPath(\(instanceObj), \(path))")
    paths.append(path)
    
    pathPtr!.pointee = .init(paths.count - 1)
    
    return XR_SUCCESS
}

func xrPathToString(instance: XrInstance?, path: XrPath, bufferCapacityInput: UInt32, bufferCountOutput: UnsafeMutablePointer<UInt32>?, buffer: UnsafeMutablePointer<CChar>?) -> XrResult {
    guard let instance else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let instanceObj = Unmanaged<XRInstance>.fromOpaque(.init(instance)).takeUnretainedValue()
    
    guard path < paths.count else {
        return XR_ERROR_PATH_INVALID
    }
    
    let pathString = paths[Int(path)]
    
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
