// Animate a decorative copy. Never split or replace selectable page text.
(() => {
  const reduced = matchMedia("(prefers-reduced-motion: reduce)");
  if (!Intl.Segmenter) return;
  const segments = new Intl.Segmenter(undefined, { granularity: "grapheme" });
  let overlay;
  let timer;
  let dragging = false;
  function clear() {
    clearTimeout(timer);
    document.documentElement.classList.remove("selection-dancing");
    overlay?.remove();
    overlay = undefined;
  }
  function dance() {
    clear();
    const selection = getSelection();
    if (reduced.matches || dragging || !selection || selection.isCollapsed || selection.rangeCount !== 1) return;
    const range = selection.getRangeAt(0);
    // Long selections retain the glow without generating hundreds of layers.
    if (!range.toString().trim() || range.toString().length > 240) return;
    const root = range.commonAncestorContainer;
    const element = root.nodeType === Node.TEXT_NODE ? root.parentElement : root;
    if (element.closest("input, textarea, [contenteditable]")) return;
    const nodes = [];
    if (root.nodeType === Node.TEXT_NODE) nodes.push(root);
    else {
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      while (walker.nextNode()) {
        if (range.intersectsNode(walker.currentNode)) nodes.push(walker.currentNode);
      }
    }
    overlay = document.createElement("div");
    overlay.className = "selection-magic";
    overlay.setAttribute("aria-hidden", "true");
    let count = 0;
    for (const node of nodes) {
      if (node.parentElement.closest("script, style, [aria-hidden='true']")) continue;
      const start = node === range.startContainer ? range.startOffset : 0;
      const end = node === range.endContainer ? range.endOffset : node.length;
      const style = getComputedStyle(node.parentElement);
      for (const { segment, index } of segments.segment(node.data.slice(start, end))) {
        const letterRange = document.createRange();
        letterRange.setStart(node, start + index);
        letterRange.setEnd(node, start + index + segment.length);
        const rect = letterRange.getBoundingClientRect();
        if (!rect.width || !rect.height) continue;
        const letter = document.createElement("span");
        letter.textContent = segment;
        Object.assign(letter.style, {
          left: `${rect.left}px`, top: `${rect.top}px`,
          font: style.font, lineHeight: `${rect.height}px`,
          letterSpacing: style.letterSpacing,
          textTransform: style.textTransform,
        });
        letter.style.setProperty("--delay", `${(count++ % 12) * 16}ms`);
        overlay.append(letter);
      }
    }
    if (!count) return clear();
    document.body.append(overlay);
    document.documentElement.classList.add("selection-dancing");
    timer = setTimeout(clear, 800);
  }
  document.addEventListener("pointerdown", () => { dragging = true; clear(); });
  document.addEventListener("pointerup", () => { dragging = false; dance(); });
  document.addEventListener("pointercancel", () => { dragging = false; clear(); });
  document.addEventListener("selectionchange", () => {
    clear();
    if (!dragging) dance();
  });
  document.addEventListener("scroll", clear, true);
  window.addEventListener("resize", clear);
  window.addEventListener("blur", clear);
  document.addEventListener("visibilitychange", clear);
  reduced.addEventListener("change", clear);
})();
