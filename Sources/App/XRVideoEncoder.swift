//
//  XRVideoEncoder.swift
//  FruitXR
//
//  Created by user on 2025/11/12.
//

import VideoToolbox

class XRVideoEncoder {
    var session: VTCompressionSession?
    var previousFormatDescription: CMVideoFormatDescription?
    let eye: UInt32
    
    weak var delegate: (any XRVideoEncoderDelegate)?
    
    init(eye: UInt32) {
        self.eye = eye
    }
    
    func handle(ioSurface: IOSurface) {
        var pixelBuffer: Unmanaged<CVPixelBuffer>?
        let pixelBufferRes = CVPixelBufferCreateWithIOSurface(nil, ioSurface, [
            kCVPixelBufferMetalCompatibilityKey: true,
        ] as CFDictionary, &pixelBuffer)
        assert(pixelBufferRes == noErr)
        if session == nil {
            let createRes = VTCompressionSessionCreate(allocator: nil, width: .init(ioSurface.width), height: .init(ioSurface.height), codecType: kCMVideoCodecType_HEVC, encoderSpecification: [
                kVTVideoEncoderSpecification_EnableLowLatencyRateControl: true,
            ] as CFDictionary, imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: { (outputCallbackRefCon, sourceFrameRefCon, status, infoFlags, sampleBuffer) in
                let me = Unmanaged<XRVideoEncoder>.fromOpaque(outputCallbackRefCon!).takeUnretainedValue()
//                print(me)
                if let sampleBuffer {
                    me.handle(sampleBuffer: sampleBuffer)
                }
            }, refcon: Unmanaged.passUnretained(self).toOpaque(), compressionSessionOut: &session)
            assert(createRes == noErr)
            VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
            VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
            VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality, value: kCFBooleanTrue)
        }
        
        let encodeRes = VTCompressionSessionEncodeFrame(
            session!,
            imageBuffer: pixelBuffer!.takeUnretainedValue(),
            presentationTimeStamp: .zero,
            duration: .zero,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )
        assert(encodeRes == noErr)
    }
    
    private func handle(sampleBuffer: CMSampleBuffer) {
//        print(sampleBuffer)
        let currentFormatDesc = sampleBuffer.formatDescription!
        if currentFormatDesc != previousFormatDescription {
            print("Format description changed")
            previousFormatDescription = currentFormatDesc
            var psCount = 0
            assert(noErr == CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(currentFormatDesc, parameterSetIndex: 0, parameterSetPointerOut: nil, parameterSetSizeOut: nil, parameterSetCountOut: &psCount, nalUnitHeaderLengthOut: nil))
            var videoInitialize = TBVideoInitialize()
            videoInitialize.parameterSets = []
            for i in 0..<psCount {
                var ptr: UnsafePointer<UInt8>?
                var size = 0
                assert(noErr == CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(currentFormatDesc, parameterSetIndex: i, parameterSetPointerOut: &ptr, parameterSetSizeOut: &size, parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil))
                let data = Data(bytes: ptr!, count: size)
                videoInitialize.parameterSets.append(data)
            }
            videoInitialize.eye = eye
            videoInitialize.codec = .hevc
//            videoInitialize.initializeCount = appDelegate.videoEncoderInitializedCount
//            appDelegate.videoEncoderInitializedCount += 1
            var msg = ToBrowser()
            msg.message = .videoInitialize(videoInitialize)
            delegate?.send(message: msg)
        }
        guard let data = try? sampleBuffer.dataBuffer?.dataBytes() else {
            return
        }
        var msg = ToBrowser()
        var vd = TBVideoData()
        vd.eye = eye
        vd.content = data
        for attachment in sampleBuffer.sampleAttachments {
            guard let value = attachment[.notSync] as? NSNumber else {
                continue
            }
            vd.keyframe = !value.boolValue
        }
        msg.message = .videoData(vd)
        delegate?.send(message: msg)
    }
}
