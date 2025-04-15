//
//  XRServerSwapchain.swift
//  FruitXR
//
//  Created by user on 2025/04/09.
//

import AppKit
import IOSurface

class XRServerSwapchain: NSObject {
    var surfaces: [IOSurface] = []
    let window = NSWindow(contentRect: .init(origin: .zero, size: .zero), styleMask: .titled, backing: .buffered, defer: true)
    let view = NSView()

    override init() {
        super.init()
        view.wantsLayer = true
        window.title = "FruitXR Swapchain \(self)"
        window.contentView = view
        window.makeKeyAndOrderFront(self)
    }
    
    @objc(addIOSurface:) func add(ioSurface: IOSurface) {
        surfaces.append(ioSurface)
        window.setContentSize(.init(width: ioSurface.width, height: ioSurface.height))
    }
    
    @objc(switchSurfaceTo:) func switchSurface(to index: Int32) {
        view.layer!.contents = surfaces[Int(index)]
    }
}
