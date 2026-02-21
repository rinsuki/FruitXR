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
    let baseTime = mach_absolute_time()
    var scale: mach_timebase_info_data_t = .init()
    let queue = DispatchQueue(label: "net.rinsuki.apps.FruitXR.XRVideoEncoder", qos: .userInteractive)
    
    init(eye: UInt32) {
        mach_timebase_info(&scale)
        self.eye = eye
    }
    
    func handle(ioSurface: IOSurface) {
        var pixelBuffer: Unmanaged<CVPixelBuffer>?
        let pixelBufferRes = CVPixelBufferCreateWithIOSurface(nil, ioSurface, [
            kCVPixelBufferMetalCompatibilityKey: true,
        ] as CFDictionary, &pixelBuffer)
        assert(pixelBufferRes == noErr)
        handle(pixelBuffer: pixelBuffer!.takeRetainedValue())
    }
    
    func handle(pixelBuffer: CVPixelBuffer) {
        if session == nil {
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let createRes = VTCompressionSessionCreate(allocator: nil, width: .init(2064 * 2), height: .init(2208), codecType: kCMVideoCodecType_HEVC, encoderSpecification: [
//                kVTVideoEncoderSpecification_EnableLowLatencyRateControl: true,
                kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder: true,
            ] as CFDictionary, imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: { (outputCallbackRefCon, sourceFrameRefCon, status, infoFlags, sampleBuffer) in
                let me = Unmanaged<XRVideoEncoder>.fromOpaque(outputCallbackRefCon!).takeUnretainedValue()
//                print(me)
                if let sampleBuffer {
                    me.handle(sampleBuffer: sampleBuffer)
                }
            }, refcon: Unmanaged.passUnretained(self).toOpaque(), compressionSessionOut: &session)
            assert(createRes == noErr)
            VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_MaxFrameDelayCount, value: 0 as CFNumber)
            VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_HEVC_Main_AutoLevel)
            VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_ConstantBitRate, value: 20_000_000 as CFNumber)
            VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: 120 as CFNumber)
            VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
            VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
            VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality, value: kCFBooleanTrue)
        }
        
        let encodeRes = VTCompressionSessionEncodeFrame(
            session!,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: .init(
                value: Int64((mach_absolute_time() - baseTime)) * Int64(scale.numer) / 1000,
                timescale: CMTimeScale(scale.denom * 1_000_000)
            ),
            duration: .init(value: 1, timescale: 120),
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )
        assert(encodeRes == noErr)
    }
    
    private func handle(sampleBuffer: CMSampleBuffer) {
//        print(sampleBuffer.presentationTimeStamp.seconds)
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
