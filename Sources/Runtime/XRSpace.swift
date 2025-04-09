//
//  XRSpace.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

import Foundation

class XRSpace {
    private(set) var destroyed = false
    
    func destroy() {
        destroyed = true
    }
    
    func locate(baseSpace: XrSpace?, time: XrTime, spaceLocation: inout XrSpaceLocation) -> XrResult {
        print("STUB: XRSpace.locate(\(baseSpace), \(time), \(spaceLocation))")
        spaceLocation.locationFlags = XR_SPACE_LOCATION_POSITION_VALID_BIT | XR_SPACE_LOCATION_ORIENTATION_VALID_BIT
        spaceLocation.pose.position = .init(x: 0, y: 0, z: 0)
        spaceLocation.pose.orientation = .init(x: 0, y: 0, z: 0, w: 1)
        return XR_SUCCESS
    }
}

func xrCreateActionSpace(session: XrSession?, createInfo: UnsafePointer<XrActionSpaceCreateInfo>?, spacePtr: UnsafeMutablePointer<XrSpace?>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let space = XRSpace()
    let ptr = Unmanaged.passRetained(space).toOpaque()
    spacePtr!.pointee = OpaquePointer(ptr)
    
    print("STUB: xrCreateActionSpace(\(session), \(createInfo?.pointee))")
    
    return XR_SUCCESS
}

func xrCreateReferenceSpace(session: XrSession?, createInfo: UnsafePointer<XrReferenceSpaceCreateInfo>?, spacePtr: UnsafeMutablePointer<XrSpace?>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let space = XRSpace()
    let ptr = Unmanaged.passRetained(space).toOpaque()
    spacePtr!.pointee = OpaquePointer(ptr)
    
    print("STUB: xrCreateReferenceSpace(\(session), \(createInfo?.pointee))")
    
    return XR_SUCCESS
}

func xrDestroySpace(space: XrSpace?) -> XrResult {
    guard let space else {
        return XR_ERROR_HANDLE_INVALID
    }

    autoreleasepool {
        let spaceObj = Unmanaged<XRSpace>.fromOpaque(.init(space)).takeUnretainedValue()
        spaceObj.destroy()
    }
    
    return XR_SUCCESS
}

func xrLocateSpace(space: XrSpace?, baseSpace: XrSpace?, time: XrTime, spaceLocation: UnsafeMutablePointer<XrSpaceLocation>?) -> XrResult {
    guard let space else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let spaceObj = Unmanaged<XRSpace>.fromOpaque(.init(space)).takeUnretainedValue()
    spaceObj.locate(baseSpace: baseSpace, time: time, spaceLocation: &spaceLocation!.pointee)
    
    return XR_SUCCESS
}


