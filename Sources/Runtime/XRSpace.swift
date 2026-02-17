//
//  XRSpace.swift
//  FruitXR
//
//  Created by user on 2025/03/23.
//

import Foundation

class XRSpace {
    let session: XRSession
    private(set) var destroyed = false
    
    init(session: XRSession) {
        self.session = session
    }
    
    func destroy() {
        destroyed = true
    }
    
    func locate(baseSpace: XRSpace?, time: XrTime, spaceLocation: inout XrSpaceLocation) -> XrResult {
        print("STUB: XRSpace.locate(self=\(self), \(baseSpace), \(time), \(spaceLocation))")
        spaceLocation.locationFlags = XR_SPACE_LOCATION_POSITION_VALID_BIT | XR_SPACE_LOCATION_ORIENTATION_VALID_BIT
        spaceLocation.pose.position = .init(x: 0, y: 0, z: 0)
        spaceLocation.pose.orientation = .init(x: 0, y: 0, z: 0, w: 1)
        return XR_SUCCESS
    }
}

class XRActionSpace: XRSpace, CustomStringConvertible {
    let action: XRAction
    
    init(session: XRSession, action: XRAction) {
        self.action = action
        super.init(session: session)
    }

    var description: String {
        return "XRActionSpace(action=\(action))"
    }
}

func xrCreateActionSpace(session: XrSession?, createInfo: UnsafePointer<XrActionSpaceCreateInfo>?, spacePtr: UnsafeMutablePointer<XrSpace?>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    
    let actionPtr = createInfo?.pointee.action
    let action = Unmanaged<XRAction>.fromOpaque(.init(actionPtr!)).takeUnretainedValue()
    
    let space = XRActionSpace(session: sessionObj, action: action)
    let ptr = Unmanaged.passRetained(space).toOpaque()
    spacePtr!.pointee = OpaquePointer(ptr)
    
    print("STUB: xrCreateActionSpace(\(session), \(action), \(createInfo?.pointee))")
    
    return XR_SUCCESS
}

class XRReferenceSpace: XRSpace, CustomStringConvertible {
    let referenceSpaceType: XrReferenceSpaceType
    
    init(session: XRSession, referenceSpaceType: XrReferenceSpaceType) {
        self.referenceSpaceType = referenceSpaceType
        super.init(session: session)
    }
    
    var description: String {
        return "XRReferenceSpace(type=\(referenceSpaceType))"
    }
}

func xrCreateReferenceSpace(session: XrSession?, createInfo: UnsafePointer<XrReferenceSpaceCreateInfo>?, spacePtr: UnsafeMutablePointer<XrSpace?>?) -> XrResult {
    guard let session else {
        return XR_ERROR_HANDLE_INVALID
    }
    
    let sessionObj = Unmanaged<XRSession>.fromOpaque(.init(session)).takeUnretainedValue()
    let space = XRReferenceSpace(session: sessionObj, referenceSpaceType: createInfo!.pointee.referenceSpaceType)
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
    let baseSpaceObj: XRSpace?
    if let baseSpace {
        baseSpaceObj = Unmanaged<XRSpace>.fromOpaque(.init(baseSpace)).takeUnretainedValue()
    } else {
        baseSpaceObj = nil
    }

    return spaceObj.locate(baseSpace: baseSpaceObj, time: time, spaceLocation: &spaceLocation!.pointee)
}
