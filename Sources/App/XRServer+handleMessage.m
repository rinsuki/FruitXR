//
//  some.c
//  FruitXR
//
//  Created by user on 2025/04/04.
//

#include "FruitXR_IPCServer.h"
#include <stdio.h>
#import <IOSurface/IOSurface.h>
#import <Foundation/Foundation.h>
#import "FruitXR-Swift.h"
@import AppKit;

#define appDelegate ((AppDelegate*)NSApp.delegate)

kern_return_t FI_S_InstanceCreate(mach_port_t server_port, mach_port_t* instance_port) {
    *instance_port = [XRServer.shared.createServerInstanceObject sendPort];
    return KERN_SUCCESS;
}

kern_return_t FI_S_SessionCreate(mach_port_t instance_port, mach_port_t* session_port) {
    XRServerInstance* instance = [XRServer.shared.instances objectForKey:@(instance_port)];
    if (instance == NULL) return KERN_FAILURE;
    XRServerSession* session = [instance createSession];
    *session_port = [session sendPort];
    return KERN_SUCCESS;
}

kern_return_t FI_S_SwapchainCreate(mach_port_t session_port, mach_port_t* swapchain_port, uint32_t* swapchain_id) {
    XRServerSession* session = [XRServer.shared.sessions objectForKey:@(session_port)];
    if (session == NULL) return KERN_FAILURE;
    XRServerSwapchain* swapchain = [session createSwapchain];
    *swapchain_port = [swapchain sendPort];
    *swapchain_id = [swapchain remoteId];
    return KERN_SUCCESS;
}

kern_return_t FI_S_SwapchainAddIOSurface(mach_port_t swapchain_port, mach_port_t surface_port) {
    IOSurfaceRef surface = IOSurfaceLookupFromMachPort(surface_port);
    NSLog(@"Received IOSurface: %@", surface);

    XRServerSwapchain* swapchain = [XRServer.shared.swapchains objectForKey:@(swapchain_port)];
    if (swapchain == NULL) return KERN_FAILURE;
    [swapchain addIOSurface: (__bridge IOSurface * _Nonnull)(surface)];
    return KERN_SUCCESS;
}

kern_return_t FI_S_SwapchainSwitch(mach_port_t swapchain_port, int32_t index) {
    XRServerSwapchain* swapchain = [XRServer.shared.swapchains objectForKey:@(swapchain_port)];
    if (swapchain == NULL) return KERN_FAILURE;
    [swapchain switchSurfaceTo: index];
    
    return KERN_SUCCESS;
}

kern_return_t FI_S_EndFrame(mach_port_t session_port, EndFrameInfo end_info) {
    XRServerSession* session = [XRServer.shared.sessions objectForKey:@(session_port)];
    if (session == NULL) return KERN_FAILURE;
    [session endFrameWithInfo: end_info];
    
    return KERN_SUCCESS;
}
