//
//  getInstanceAddr.swift
//  FruitXR
//
//  Created by user on 2025/03/12.
//

import os.log

func getInstanceProcAddr(instance: XrInstance?, name: UnsafePointer<Int8>?, functionPtr: UnsafeMutablePointer<PFN_xrVoidFunction?>?) -> XrResult {
    let log = Logger(subsystem: "net.rinsuki.apps.FruitXRRuntime", category: "getInstanceProcAddr")
    guard let functionPtr else {
        log.error("functionPtr is nil")
        return XR_ERROR_FUNCTION_UNSUPPORTED
    }
    guard let namePtr = name else {
        log.error("name is nil")
        functionPtr.pointee = nil
        return XR_ERROR_FUNCTION_UNSUPPORTED
    }
    let name = String(cString: namePtr)
    switch name {
    case "xrEnumerateInstanceExtensionProperties":
        functionPtr.pointee = unsafeBitCast(
            xrEnumerateInstanceExtensionProperties as PFN_xrEnumerateInstanceExtensionProperties,
            to: PFN_xrVoidFunction.self
        )
    case "xrCreateInstance":
        functionPtr.pointee = unsafeBitCast(
            xrCreateInstance as PFN_xrCreateInstance,
            to: PFN_xrVoidFunction.self
        )
    case "xrGetInstanceProperties":
        functionPtr.pointee = unsafeBitCast(
            xrGetInstanceProperties as PFN_xrGetInstanceProperties,
            to: PFN_xrVoidFunction.self
        )
    case "xrGetSystem":
        functionPtr.pointee = unsafeBitCast(
            xrGetSystem as PFN_xrGetSystem,
            to: PFN_xrVoidFunction.self
        )
    case "xrEnumerateEnvironmentBlendModes":
        functionPtr.pointee = unsafeBitCast(
            xrEnumerateEnvironmentBlendModes as PFN_xrEnumerateEnvironmentBlendModes,
            to: PFN_xrVoidFunction.self
        )
    case "xrEnumerateViewConfigurations":
        functionPtr.pointee = unsafeBitCast(
            xrEnumerateViewConfigurations as PFN_xrEnumerateViewConfigurations,
            to: PFN_xrVoidFunction.self
        )
    case "xrGetViewConfigurationProperties":
        functionPtr.pointee = unsafeBitCast(
            xrGetViewConfigurationProperties as PFN_xrGetViewConfigurationProperties,
            to: PFN_xrVoidFunction.self
        )
    case "xrEnumerateViewConfigurationViews":
        functionPtr.pointee = unsafeBitCast(
            xrEnumerateViewConfigurationViews as PFN_xrEnumerateViewConfigurationViews,
            to: PFN_xrVoidFunction.self
        )
    case "xrDestroyInstance":
        functionPtr.pointee = unsafeBitCast(
            xrDestroyInstance as PFN_xrDestroyInstance,
            to: PFN_xrVoidFunction.self
        )
    case "xrCreateSession":
        functionPtr.pointee = unsafeBitCast(
            xrCreateSession as PFN_xrCreateSession,
            to: PFN_xrVoidFunction.self
        )
    case "xrEnumerateReferenceSpaces":
        functionPtr.pointee = unsafeBitCast(
            xrEnumerateReferenceSpaces as PFN_xrEnumerateReferenceSpaces,
            to: PFN_xrVoidFunction.self
        )
    case "xrCreateActionSet":
        functionPtr.pointee = unsafeBitCast(
            xrCreateActionSet as PFN_xrCreateActionSet,
            to: PFN_xrVoidFunction.self
        )
    case "xrStringToPath":
        functionPtr.pointee = unsafeBitCast(
            xrStringToPath as PFN_xrStringToPath,
            to: PFN_xrVoidFunction.self
        )
    case "xrDestroySpace":
        functionPtr.pointee = unsafeBitCast(
            xrDestroySpace as PFN_xrDestroySpace,
            to: PFN_xrVoidFunction.self
        )
    case "xrDestroyActionSet":
        functionPtr.pointee = unsafeBitCast(
            xrDestroyActionSet as PFN_xrDestroyActionSet,
            to: PFN_xrVoidFunction.self
        )
    case "xrDestroySession":
        functionPtr.pointee = unsafeBitCast(
            xrDestroySession as PFN_xrDestroySession,
            to: PFN_xrVoidFunction.self
        )
    case "xrEndSession":
        functionPtr.pointee = unsafeBitCast(
            xrEndSession as PFN_xrEndSession,
            to: PFN_xrVoidFunction.self
        )
    case "xrCreateAction":
        functionPtr.pointee = unsafeBitCast(
            xrCreateAction as PFN_xrCreateAction,
            to: PFN_xrVoidFunction.self
        )
    case "xrDestroyAction":
        functionPtr.pointee = unsafeBitCast(
            xrDestroyAction as PFN_xrDestroyAction,
            to: PFN_xrVoidFunction.self
        )
    case "xrSuggestInteractionProfileBindings":
        functionPtr.pointee = unsafeBitCast(
            xrSuggestInteractionProfileBindings as PFN_xrSuggestInteractionProfileBindings,
            to: PFN_xrVoidFunction.self
        )
    case "xrCreateActionSpace":
        functionPtr.pointee = unsafeBitCast(
            xrCreateActionSpace as PFN_xrCreateActionSpace,
            to: PFN_xrVoidFunction.self
        )
    case "xrAttachSessionActionSets":
        functionPtr.pointee = unsafeBitCast(
            xrAttachSessionActionSets as PFN_xrAttachSessionActionSets,
            to: PFN_xrVoidFunction.self
        )
    case "xrCreateReferenceSpace":
        functionPtr.pointee = unsafeBitCast(
            xrCreateReferenceSpace as PFN_xrCreateReferenceSpace,
            to: PFN_xrVoidFunction.self
        )
    case "xrGetSystemProperties":
        functionPtr.pointee = unsafeBitCast(
            xrGetSystemProperties as PFN_xrGetSystemProperties,
            to: PFN_xrVoidFunction.self
        )
    case "xrEnumerateSwapchainFormats":
        functionPtr.pointee = unsafeBitCast(
            xrEnumerateSwapchainFormats as PFN_xrEnumerateSwapchainFormats,
            to: PFN_xrVoidFunction.self
        )
    case "xrCreateSwapchain":
        functionPtr.pointee = unsafeBitCast(
            xrCreateSwapchain as PFN_xrCreateSwapchain,
            to: PFN_xrVoidFunction.self
        )
    case "xrEnumerateSwapchainImages":
        functionPtr.pointee = unsafeBitCast(
            xrEnumerateSwapchainImages as PFN_xrEnumerateSwapchainImages,
            to: PFN_xrVoidFunction.self
        )
    case "xrDestroySwapchain":
        functionPtr.pointee = unsafeBitCast(
            xrDestroySwapchain as PFN_xrDestroySwapchain,
            to: PFN_xrVoidFunction.self
        )
    case "xrPollEvent":
        functionPtr.pointee = unsafeBitCast(
            xrPollEvent as PFN_xrPollEvent,
            to: PFN_xrVoidFunction.self
        )
    case "xrBeginSession":
        functionPtr.pointee = unsafeBitCast(
            xrBeginSession as PFN_xrBeginSession,
            to: PFN_xrVoidFunction.self
        )
    case "xrSyncActions":
        functionPtr.pointee = unsafeBitCast(
            xrSyncActions as PFN_xrSyncActions,
            to: PFN_xrVoidFunction.self
        )
    case "xrGetActionStateFloat":
        functionPtr.pointee = unsafeBitCast(
            xrGetActionStateFloat as PFN_xrGetActionStateFloat,
            to: PFN_xrVoidFunction.self
        )
    case "xrGetActionStatePose":
        functionPtr.pointee = unsafeBitCast(
            xrGetActionStatePose as PFN_xrGetActionStatePose,
            to: PFN_xrVoidFunction.self
        )
    case "xrGetActionStateBoolean":
        functionPtr.pointee = unsafeBitCast(
            xrGetActionStateBoolean as PFN_xrGetActionStateBoolean,
            to: PFN_xrVoidFunction.self
        )
    case "xrGetActionStateVector2f":
        functionPtr.pointee = unsafeBitCast(
            xrGetActionStateVector2f as PFN_xrGetActionStateVector2f,
            to: PFN_xrVoidFunction.self
        )
    case "xrWaitFrame":
        functionPtr.pointee = unsafeBitCast(
            xrWaitFrame as PFN_xrWaitFrame,
            to: PFN_xrVoidFunction.self
        )
    case "xrBeginFrame":
        functionPtr.pointee = unsafeBitCast(
            xrBeginFrame as PFN_xrBeginFrame,
            to: PFN_xrVoidFunction.self
        )
    case "xrEndFrame":
        functionPtr.pointee = unsafeBitCast(
            xrEndFrame as PFN_xrEndFrame,
            to: PFN_xrVoidFunction.self
        )
    case "xrLocateViews":
        functionPtr.pointee = unsafeBitCast(
            xrLocateViews as PFN_xrLocateViews,
            to: PFN_xrVoidFunction.self
        )
    case "xrLocateSpace":
        functionPtr.pointee = unsafeBitCast(
            xrLocateSpace as PFN_xrLocateSpace,
            to: PFN_xrVoidFunction.self
        )
    case "xrAcquireSwapchainImage":
        functionPtr.pointee = unsafeBitCast(
            xrAcquireSwapchainImage as PFN_xrAcquireSwapchainImage,
            to: PFN_xrVoidFunction.self
        )
    case "xrWaitSwapchainImage":
        functionPtr.pointee = unsafeBitCast(
            xrWaitSwapchainImage as PFN_xrWaitSwapchainImage,
            to: PFN_xrVoidFunction.self
        )
    case "xrReleaseSwapchainImage":
        functionPtr.pointee = unsafeBitCast(
            xrReleaseSwapchainImage as PFN_xrReleaseSwapchainImage,
            to: PFN_xrVoidFunction.self
        )
    case "xrApplyHapticFeedback":
        functionPtr.pointee = unsafeBitCast(
            xrApplyHapticFeedback as PFN_xrApplyHapticFeedback,
            to: PFN_xrVoidFunction.self
        )
    case "xrGetCurrentInteractionProfile":
        functionPtr.pointee = unsafeBitCast(
            xrGetCurrentInteractionProfile as PFN_xrGetCurrentInteractionProfile,
            to: PFN_xrVoidFunction.self
        )
    case "xrGetReferenceSpaceBoundsRect":
        functionPtr.pointee = unsafeBitCast(
            xrGetReferenceSpaceBoundsRect as PFN_xrGetReferenceSpaceBoundsRect,
            to: PFN_xrVoidFunction.self
        )
    case "xrPathToString":
        functionPtr.pointee = unsafeBitCast(
            xrPathToString as PFN_xrPathToString,
            to: PFN_xrVoidFunction.self
        )
    case "xrResultToString":
        functionPtr.pointee = unsafeBitCast(
            xrResultToString as PFN_xrResultToString,
            to: PFN_xrVoidFunction.self
        )
    case "xrRequestExitSession":
        functionPtr.pointee = unsafeBitCast(
            xrRequestExitSession as PFN_xrRequestExitSession,
            to: PFN_xrVoidFunction.self
        )
    // -- METAL --
    // X2 is for Unity's WIP OpenXR macOS plugin (com.unity.xr.openxr@1.14.2)
    // It seems completely same as XR_KHR_metal_enable except for name of extension and function
    case "xrGetMetalGraphicsRequirementsKHR", "xrGetMetalGraphicsRequirementsKHRX2":
        functionPtr.pointee = unsafeBitCast(
            xrGetMetalGraphicsRequirementsKHR as PFN_xrGetMetalGraphicsRequirementsKHR,
            to: PFN_xrVoidFunction.self
        )
    default:
        log.warning("STUB: app wants \(name)")
        functionPtr.pointee = nil
        return XR_ERROR_FUNCTION_UNSUPPORTED
    }
    return XR_SUCCESS
}

let availableExtensionsAndVersions = [
    ("XR_KHR_metal_enable", 1),
    ("XR_KHRX2_metal_enable", 1),
]

func xrEnumerateInstanceExtensionProperties(layerName: UnsafePointer<Int8>?, propertyCapacityInput: UInt32, propertyCountOutput: UnsafeMutablePointer<UInt32>?, properties: UnsafeMutablePointer<XrExtensionProperties>?) -> XrResult {
    let layerName = layerName.map { String(cString: $0) }
    let log = Logger(subsystem: "net.rinsuki.apps.FruitXRRuntime", category: "xrEnumerateInstanceExtensionProperties")
    log.warning("STUB: layerName=\(layerName ?? "nil")")
    
    guard let properties else {
        propertyCountOutput!.pointee = UInt32(availableExtensionsAndVersions.count)
        return XR_SUCCESS
    }
    
    var i = 0
    
    while i < availableExtensionsAndVersions.count, i < propertyCapacityInput {
        let (extensionName, version) = availableExtensionsAndVersions[i]
        let p = properties.advanced(by: i)
        p.pointee.extensionVersion = .init(version)
        extensionName.withCString { bytes in
            _ = strcpy(&p.pointee.extensionName.0, bytes)
        }
        i += 1
    }
    
    propertyCountOutput?.pointee = .init(i)
    
    return XR_SUCCESS
}

@_cdecl("xrNegotiateLoaderRuntimeInterface")
func xrNegotiateLoaderRuntimeInterface(loaderInfo: UnsafePointer<XrNegotiateLoaderInfo>, runtimeRequest: UnsafeMutablePointer<XrNegotiateRuntimeRequest>) -> XrResult {
    let log = Logger(subsystem: "net.rinsuki.apps.FruitXRRuntime", category: "xrNegotiateLoaderRuntimeInterface")
    
    guard loaderInfo.pointee.structType == XR_LOADER_INTERFACE_STRUCT_LOADER_INFO else {
        log.error("loaderInfo.structType is not XR_LOADER_INTERFACE_STRUCT_LOADER_INFO")
        return XR_ERROR_INITIALIZATION_FAILED
    }
    
    guard loaderInfo.pointee.structVersion == XR_LOADER_INFO_STRUCT_VERSION else {
        log.error("loaderInfo.structVersion is not XR_LOADER_INFO_STRUCT_VERSION")
        return XR_ERROR_INITIALIZATION_FAILED
    }
    
    guard loaderInfo.pointee.structSize == MemoryLayout<XrNegotiateLoaderInfo>.size else {
        log.error("loaderInfo.structSize is not MemoryLayout<XrLoaderInterface>.size")
        return XR_ERROR_INITIALIZATION_FAILED
    }
    
    guard runtimeRequest.pointee.structType == XR_LOADER_INTERFACE_STRUCT_RUNTIME_REQUEST else {
        log.error("runtimeRequest.pointee.structType is not XR_LOADER_INTERFACE_STRUCT_RUNTIME_REQUEST")
        return XR_ERROR_INITIALIZATION_FAILED
    }
    
    guard runtimeRequest.pointee.structVersion == XR_RUNTIME_INFO_STRUCT_VERSION else {
        log.error("runtimeRequest.pointee.structVersion is not XR_RUNTIME_INFO_STRUCT_VERSION")
        return XR_ERROR_INITIALIZATION_FAILED
    }
    
    guard runtimeRequest.pointee.structSize == MemoryLayout<XrNegotiateRuntimeRequest>.size else {
        log.error("runtimeRequest.pointee.structSize is not MemoryLayout<XrNegotiateRuntimeRequest>.size")
        return XR_ERROR_INITIALIZATION_FAILED
    }
    
    runtimeRequest.pointee.runtimeApiVersion = loaderInfo.pointee.minApiVersion
    runtimeRequest.pointee.runtimeInterfaceVersion = loaderInfo.pointee.minInterfaceVersion
    runtimeRequest.pointee.getInstanceProcAddr = getInstanceProcAddr
    
    log.warning("STUB")
    return XR_SUCCESS
}
