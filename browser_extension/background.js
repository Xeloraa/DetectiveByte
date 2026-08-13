// Detective Byte — background service worker
//
// Relays a video URL from the content script to the desktop app's local
// bridge server. Runs from the background worker (not the content script)
// so the request isn't subject to the page's own CSP/CORS restrictions.

const BRIDGE_URL = 'http://127.0.0.1:8791/investigate';

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type !== 'byte-video-play' || !message.url) return;

  fetch(BRIDGE_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ url: message.url }),
  }).catch(() => {
    // Detective Byte desktop app isn't running right now — ignore.
  });
});
