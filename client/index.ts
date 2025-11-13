import { create, fromBinary, toBinary, type MessageInitShape } from "@bufbuild/protobuf"
import { FromBrowserSchema, ToBrowserSchema, VideoCodec, type FromBrowser, type ToBrowser } from "./gen/main_pb.js"
import { parseInitNALUHEVC } from "./utils/hevc_parser.js"

class EyeRenderer {
    videoDecoder = this.createNewDecoder()
    parameterSets: Uint8Array[] = []
    ts = 0
    canvas = document.createElement("canvas")
    ctx = this.canvas.getContext("2d")!
    prev = performance.now()

    constructor() {
        document.body.appendChild(this.canvas)
    }

    createNewDecoder() {
        return new VideoDecoder({
            error: e => {
                alert(`VideoDecoder error: ${e.message}`)
            },
            output: frame => {
                this.canvas.width = frame.codedWidth
                this.canvas.height = frame.codedHeight
                this.ctx.drawImage(frame, 0, 0)
                frame.close()
                const now = performance.now()
                const fps = 1000 / (now - this.prev)
                this.prev = now
                document.title = `FPS: ${fps.toFixed(2)}`
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
        // wrong way to convert length-prefixed to 0001-prefixed
        nalContent.set(new Uint8Array([0, 0, 0, 1]), offset)
        offset += 4
        nalContent.set(data.subarray(4), offset)
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

    constructor(public session: XRSession, public ws: WebSocket) {
        ws.binaryType = "arraybuffer"
        ws.addEventListener("open", () => {
            this.handleOpen()
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
            console.log(v.content)
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
        xr.requestSession("immersive-vr").then(session => {
            const ws = new WebSocket("ws://localhost:18034/decoder")
            new Client(session, ws)
        })
    })
}

main()