let liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
  params: { _csrf_token: document.querySelector("meta[name='csrf-token']").getAttribute("content") }
})
liveSocket.connect()
window.liveSocket = liveSocket
