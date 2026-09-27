// Small bubbles escape from new spots while the icon is hovered.
(() => {
  const icon = document.querySelector(".icon-float");
  if (!icon) return;

  const random = (min, max) => min + Math.random() * (max - min);
  const bubbles = Array.from({ length: 18 }, () => {
    const bubble = document.createElement("span");
    bubble.className = "mana-bubble";
    bubble.setAttribute("aria-hidden", "true");
    bubble.style.setProperty("--duration", `${random(1.25, 2.1).toFixed(2)}s`);
    bubble.style.setProperty("--delay", `${random(0, 0.9).toFixed(2)}s`);
    bubble.addEventListener("animationiteration", () => scatter(bubble));
    icon.append(bubble);
    return bubble;
  });

  function scatter(bubble) {
    bubble.style.left = `${random(22, 78).toFixed(1)}%`;
    bubble.style.bottom = `${random(15, 62).toFixed(1)}%`;
    bubble.style.setProperty("--size", `${random(6, 16).toFixed(1)}px`);
    bubble.style.setProperty("--drift", `${random(-28, 28).toFixed(1)}px`);
    bubble.style.setProperty("--rise", `${random(55, 120).toFixed(1)}px`);
  }

  icon.addEventListener("mouseenter", () => bubbles.forEach(scatter));
  bubbles.forEach(scatter);
})();
