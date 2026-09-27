// A quiet wind through square tiles; the pointer lights them like a torch.
(() => {
  const hero = document.querySelector(".hero");
  const canvas = document.querySelector(".mana-grid");
  const context = canvas?.getContext("2d");
  if (!hero || !canvas || !context) return;

  const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)");
  const tile = 32;
  const torchRadius = 190;
  let width = 0;
  let height = 0;
  let pointerX = -torchRadius;
  let pointerY = -torchRadius;
  let torch = 0;
  let torchTarget = 0;
  let frame = 0;
  let lastFrame = 0;

  function draw(time) {
    if (!width || !height) return;
    torch += reducedMotion.matches
      ? torchTarget - torch
      : (torchTarget - torch) * 0.16;
    context.clearRect(0, 0, width, height);

    if (torch > 0.001) {
      const glow = context.createRadialGradient(
        pointerX,
        pointerY,
        0,
        pointerX,
        pointerY,
        torchRadius,
      );
      glow.addColorStop(0, `rgba(67, 162, 255, ${0.14 * torch})`);
      glow.addColorStop(1, "rgba(67, 162, 255, 0)");
      context.fillStyle = glow;
      context.fillRect(
        pointerX - torchRadius,
        pointerY - torchRadius,
        torchRadius * 2,
        torchRadius * 2,
      );
    }

    for (let y = 0; y < height; y += tile) {
      for (let x = 0; x < width; x += tile) {
        const centerX = x + tile / 2;
        const centerY = y + tile / 2;
        // Offset sine waves produce diagonal, drifting bands instead of a blinking grid.
        const wave = Math.sin(
          centerX * 0.017 + centerY * 0.027 - time * 0.0012,
        );
        const eddy = Math.sin(
          centerY * 0.019 - centerX * 0.009 + time * 0.00055,
        );
        const wind = Math.max(0, (wave + eddy + 0.4) / 2.4) ** 2;
        const distance = Math.hypot(centerX - pointerX, centerY - pointerY);
        const light = torch * Math.max(0, 1 - distance / torchRadius) ** 2;
        const seed =
          Math.sin((x / tile + 1) * 127.1 + (y / tile + 1) * 311.7) *
          43758.5453;
        const grain = seed - Math.floor(seed);
        const fill = 0.025 + wind * 0.17 + grain * 0.105 + light * 0.72;

        context.fillStyle = `rgba(76, 157, 247, ${fill})`;
        context.fillRect(x, y, tile, tile);
      }
    }
  }

  function animate(time) {
    frame = requestAnimationFrame(animate);
    if (time - lastFrame < 32) return;
    lastFrame = time;
    draw(time);
  }

  function setMotion() {
    cancelAnimationFrame(frame);
    frame = 0;
    if (reducedMotion.matches || document.hidden) {
      draw(0);
    } else {
      frame = requestAnimationFrame(animate);
    }
  }

  function resize() {
    const bounds = canvas.getBoundingClientRect();
    width = bounds.width;
    height = bounds.height;
    const scale = Math.min(devicePixelRatio || 1, 2);
    canvas.width = Math.round(width * scale);
    canvas.height = Math.round(height * scale);
    context.setTransform(scale, 0, 0, scale, 0, 0);
    draw(reducedMotion.matches ? 0 : performance.now());
  }

  hero.addEventListener("pointermove", (event) => {
    if (event.pointerType !== "mouse" && event.pointerType !== "pen") return;
    const bounds = canvas.getBoundingClientRect();
    pointerX = event.clientX - bounds.left;
    pointerY = event.clientY - bounds.top;
    torchTarget = 1;
    if (reducedMotion.matches) draw(0);
  });
  hero.addEventListener("pointerleave", () => {
    torchTarget = 0;
    if (reducedMotion.matches) draw(0);
  });
  reducedMotion.addEventListener("change", setMotion);
  document.addEventListener("visibilitychange", setMotion);
  new ResizeObserver(resize).observe(canvas);
  setMotion();
})();
