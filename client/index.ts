import { create, fromBinary, toBinary, type MessageInitShape } from "@bufbuild/protobuf"
import { FromBrowserSchema, ToBrowserSchema, VideoCodec, type FromBrowser, type ToBrowser } from "./gen/main_pb.js"
import { parseInitNALUHEVC } from "./utils/hevc_parser.js"
import { createShaderProgram } from "./shader.js"

class EyeRenderer {
    videoDecoder = this.createNewDecoder()
    parameterSets: Uint8Array[] = []
    ts = 0
    prev = performance.now()
    counts = 0
    lastFrame: VideoFrame | null = null

    createNewDecoder() {
        return new VideoDecoder({
            error: e => {
                alert(`VideoDecoder error: ${e.message}`)
            },
            output: frame => {
                if (this.lastFrame) {
                    this.lastFrame.close()
                }
                this.lastFrame = frame
                this.counts++

                const now = performance.now()
                if (now - this.prev >= 1000) {
                    document.title = `FPS: ${this.counts}`
                    this.prev = now
                    this.counts = 0
                }
            }
        })
    }


    configure(parameterSets: Uint8Array[]) {
        this.parameterSets = parameterSets
        const vps = parameterSets[0]!
        console.log(parseInitNALUHEVC(vps))
        this.videoDecoder.configure({
            codec: parseInitNALUHEVC(vps),
            optimizeForLatency: true,
        })
        console.log("configured")
    }

    receive(data: Uint8Array, keyframe: boolean) {
        let length = 4 + data.byteLength
        for (const ps of this.parameterSets) {
            length += 4 + ps.byteLength
        }
        const nalContent = new Uint8Array(length)
        let offset = 0
        for (const ps of [...this.parameterSets]) {
            nalContent.set(new Uint8Array([0, 0, 0, 1]), offset)
            offset += 4
            nalContent.set(ps, offset)
            offset += ps.byteLength
        }
        // console.log(data)
        const reader = new DataView(data.buffer, data.byteOffset, data.byteLength)
        let readerOffset = 0
        while (readerOffset + 4 <= data.byteLength) {
            const nalSize = reader.getUint32(readerOffset)
            nalContent.set(new Uint8Array([0, 0, 0, 1]), offset)
            offset += 4
            readerOffset += 4
            nalContent.set(new Uint8Array(data.buffer, data.byteOffset + readerOffset, nalSize), offset)
            offset += nalSize
            readerOffset += nalSize
        }
        const isKey = this.parameterSets.length ? true : false
        this.parameterSets = []
        this.videoDecoder.decode(new EncodedVideoChunk({
            data: nalContent,
            timestamp: this.ts++,
            type: isKey ? "key" : "delta",
        }))
    }
}

class Client {
    eyes = [
        new EyeRenderer(),
        new EyeRenderer(),
    ] as const
    gl: WebGLRenderingContext
    glLayer: XRWebGLLayer
    referenceSpace!: XRReferenceSpace

    constructor(public session: XRSession, public ws: WebSocket) {
        // webxr setup
        const canvas = document.createElement("canvas")
        document.body.appendChild(canvas)
        this.gl = canvas.getContext("webgl", { xrCompatible: true })!
        this.glLayer = new XRWebGLLayer(this.session, this.gl)
        this.session.updateRenderState({
            baseLayer: this.glLayer,
        })
        // websocket setup
        ws.binaryType = "arraybuffer"
        ws.addEventListener("open", () => {
            this.handleOpen()
            this.setupWebXR()
        })
        ws.addEventListener("message", e => {
            if (!(e.data instanceof ArrayBuffer)) {
                alert(e.data)
                return
            }
            const data = new Uint8Array(e.data as ArrayBuffer)
            this.handleMessage(fromBinary(ToBrowserSchema, data))
        })
        ws.addEventListener("close", () => {
            session.end()
        })
        ws.addEventListener("error", e => {
            session.end()
            alert(`WebSocket error: ${e}`)
        })
    }

    async setupWebXR() {
        this.referenceSpace = await this.session.requestReferenceSpace("local-floor")
        const program = createShaderProgram(this.gl)
        this.gl.useProgram(program)

        const texCoord = this.gl.getAttribLocation(program, "a_texCoord")
        this.gl.enableVertexAttribArray(texCoord)
        const uvPos = new Float32Array([0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0])
        this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.gl.createBuffer())
        this.gl.bufferData(this.gl.ARRAY_BUFFER, uvPos, this.gl.STATIC_DRAW)
        this.gl.vertexAttribPointer(texCoord, 2, this.gl.FLOAT, false, 0, 0)
        this.gl.activeTexture(this.gl.TEXTURE0)
        this.gl.bindTexture(this.gl.TEXTURE_2D, this.gl.createTexture())
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MIN_FILTER, this.gl.LINEAR)
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_WRAP_S, this.gl.CLAMP_TO_EDGE)
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_WRAP_T, this.gl.CLAMP_TO_EDGE)
        this.gl.uniform1i(this.gl.getUniformLocation(program, "sampler0"), 0)
        this.gl.uniform1f(this.gl.getUniformLocation(this.gl.getParameter(this.gl.CURRENT_PROGRAM), "width"), 1)
        this.session.requestAnimationFrame(this.raf)
        console.log("webxr started")
    }

    raf: XRFrameRequestCallback = (time, frame) => {
        if (this.referenceSpace == null) return console.log("referenceSpace is null")
        this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, this.glLayer.framebuffer)
        const pose = frame.getViewerPose(this.referenceSpace)
        if (pose == null) {
            console.log("pose is null")
            return
        }

        // TODO: send poses
        this.sendMessage({
            message: {
                case: "currentPosition",
                value: {
                    hmd: {
                        position: {
                            x: pose.transform.position.x,
                            y: pose.transform.position.y,
                            z: pose.transform.position.z,
                        },
                        orientation: {
                            x: pose.transform.orientation.x,
                            y: pose.transform.orientation.y,
                            z: pose.transform.orientation.z,
                            w: pose.transform.orientation.w,
                        }
                    }
                }
            }
        })
        
        // draw
        let i = 0
        for (const view of pose.views) {
            const viewport = this.glLayer.getViewport(view)
            if (viewport == null) continue
            this.gl.viewport(viewport.x, viewport.y, viewport.width, viewport.height)
            const frame = this.eyes[i++]?.lastFrame
            if (frame != null) {
                this.gl.activeTexture(this.gl.TEXTURE0)
                this.gl.texImage2D(this.gl.TEXTURE_2D, 0, this.gl.RGBA, frame.codedWidth, frame.codedHeight, 0, this.gl.RGBA, this.gl.UNSIGNED_BYTE, null)
                this.gl.texSubImage2D(this.gl.TEXTURE_2D, 0, 0, 0, this.gl.RGBA, this.gl.UNSIGNED_BYTE, frame)
            }
            this.gl.uniform1f(this.gl.getUniformLocation(this.gl.getParameter(this.gl.CURRENT_PROGRAM), "left"), 0)
            this.gl.drawArrays(this.gl.TRIANGLE_FAN, 0, 4)
            this.gl.flush()
        }
        this.session.requestAnimationFrame(this.raf)
    }

    handleOpen() {
        console.log("WebSocket connected")
        this.sendMessage({
            message: {
                case: "initEncoder",
                value: {},
            }
        })
    }

    handleMessage(message: ToBrowser) {
        switch (message.message.case) {
        case "videoInitialize": {
            const v = message.message.value
            if (v.codec !== VideoCodec.HEVC) {
                alert(`Unsupported codec: ${VideoCodec[v.codec]}`)
                break
            }
            this.eyes[v.eye]!.configure(v.parameterSets.map(ps => ps!))
            console.log(v)
            break
        }
        case "videoData": {
            const v = message.message.value
            if (v.content == null) {
                alert("videoData.content is null")
                break
            }
            // console.log(v.content)
            this.eyes[v.eye]!.receive(v.content!, v.keyframe)
            break
        }
        default:
            alert(message.message.case)
            this.ws.close()
        }
    }

    sendMessage(message: MessageInitShape<typeof FromBrowserSchema>) {
        this.ws.send(toBinary(FromBrowserSchema, create(FromBrowserSchema, message)))
    }
}

function main() {
    const app = document.createElement("div")
    document.body.appendChild(app)
    const xr = navigator.xr
    if (xr == null) {
        app.innerText = "WebXR is not supported on this browser."
        return
    }

    const button = document.createElement("button")
    button.innerText = "LINK START"
    button.style.fontSize = "9vw"
    app.appendChild(button)

    button.addEventListener("click", () => {
        xr.requestSession("immersive-vr", {
            requiredFeatures: ["local-floor"],
        }).then(session => {
            const ws = new WebSocket("ws://localhost:18034/decoder")
            new Client(session, ws)
        })
    })
}

main()