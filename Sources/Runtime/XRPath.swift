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
