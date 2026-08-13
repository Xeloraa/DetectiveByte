// Detective Byte — content script
//
// Watches for the user pressing play on a video and reports the page URL
// to the extension's background worker, which hands it to the desktop app.
// Deliberately triggers on "play" rather than every click on the video —
// clicking a video also means pausing/seeking/fullscreen, which would spam
// investigations for actions that aren't "I started watching this."

(() => {
  let lastSentUrl = null;

  function notifyPlay() {
    const url = location.href;
    if (url === lastSentUrl) return;
    lastSentUrl = url;
    chrome.runtime.sendMessage({ type: 'byte-video-play', url });
  }

  function attachToVideos() {
    document.querySelectorAll('video').forEach((video) => {
      if (video.dataset.byteAttached) return;
      video.dataset.byteAttached = 'true';
      video.addEventListener('play', notifyPlay, { passive: true });
    });
  }

  attachToVideos();

  // YouTube/TikTok render videos dynamically as you scroll/navigate.
  const observer = new MutationObserver(attachToVideos);
  observer.observe(document.documentElement, { childList: true, subtree: true });

  // Both sites are single-page apps — the URL changes without a reload when
  // you move to a new video, so re-arm the dedupe check on navigation.
  let lastHref = location.href;
  setInterval(() => {
    if (location.href !== lastHref) {
      lastHref = location.href;
      lastSentUrl = null;
    }
  }, 800);
})();
