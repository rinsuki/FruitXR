import WebSocket, { WebSocketServer } from "ws"

const server = new WebSocketServer({
  port: 18034, // 0x4672, // 'Fr'
  perMessageDeflate: false,
})

let wsEncoder: WebSocket | null = null
let wsDecoder: WebSocket | null = null

server.on("connection", (ws, req) => {
  if (req.url === "/encoder") {
    if (wsEncoder != null) {
      wsEncoder.close()
    }
    wsEncoder = ws
    ws.addEventListener("message", e => {
      if (wsDecoder != null && wsDecoder.readyState === WebSocket.OPEN) {
        wsDecoder.send(e.data)
      }
    })
  } else if (req.url === "/decoder") {
    if (wsDecoder != null) {
      wsDecoder.close()
    }
    wsDecoder = ws
    ws.addEventListener("message", e => {
      if (wsEncoder != null && wsEncoder.readyState === WebSocket.OPEN) {
        wsEncoder.send(e.data)
      }
    })
  }
})
