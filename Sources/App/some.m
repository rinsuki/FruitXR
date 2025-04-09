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

kern_return_t FI_S_SwapchainCreate(mach_port_t server_port, int32_t* index) {
    *index = [appDelegate createServerSwapchainObject];
    return KERN_SUCCESS;
}

kern_return_t FI_S_SwapchainAddIOSurface(mach_port_t server_port, int32_t swapchain, mach_port_t surface_port) {
    IOSurfaceRef surface = IOSurfaceLookupFromMachPort(surface_port);
    NSLog(@"Received IOSurface: %@", surface);
    
    [appDelegate.swapchains[@(swapchain)] addIOSurface: (__bridge IOSurface * _Nonnull)(surface)];
    
    return KERN_SUCCESS;
}

kern_return_t FI_S_SwapchainSwitch(mach_port_t server_port, int32_t swapchain, int32_t index) {
    NSLog(@"Switching swapchain %d's current texture to %d", swapchain, index);
    [appDelegate.swapchains[@(swapchain)] switchSurfaceTo: index];
    
    return KERN_SUCCESS;
}
