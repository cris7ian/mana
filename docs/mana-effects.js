// Decorative feedback; the icon remains an image, not a keyboard control.
(() => {
  const hero = document.querySelector(".hero");
  const art = hero?.querySelector(".hero-art");
  const icon = art?.querySelector(".icon-float");
  if (!hero || !art || !icon) return;

  const reduced = matchMedia("(prefers-reduced-motion: reduce)");
  const ns = "http://www.w3.org/2000/svg";
  const ring = document.createElementNS(ns, "svg");
  ring.setAttribute("viewBox", "0 0 100 100");
  ring.setAttribute("class", "energy-ring");
  ring.setAttribute("aria-hidden", "true");
  const path = document.createElementNS(ns, "path");
  path.setAttribute("d", "M50 3 91 26 91 74 50 97 9 74 9 26Z");
  path.setAttribute("pathLength", "100");
  ring.append(path);
  icon.append(ring);

  let release;
  function charge() {
    if (hero.classList.contains("effects-paused")) return;
    art.classList.add("is-charged");
    if (!reduced.matches) art.classList.add("is-bursting");
  }
  function settle() {
    clearTimeout(release);
    art.classList.remove("is-charged");
  }
  icon.addEventListener("pointerenter", (event) => {
    if (event.pointerType !== "touch") charge();
  });
  icon.addEventListener("pointerleave", settle);
  icon.addEventListener("pointerdown", (event) => {
    if (event.pointerType !== "touch") return;
    clearTimeout(release);
    charge();
    release = setTimeout(settle, 850);
  });
  icon.addEventListener("pointercancel", settle);
  ring.addEventListener("animationend", (event) => {
    if (event.target === ring) art.classList.remove("is-bursting");
  });

  const sections = [hero, document.querySelector(".closing")].filter(Boolean);
  const visible = new Set();
  function update() {
    for (const section of sections) {
      section.classList.toggle("effects-paused", document.hidden || !visible.has(section));
    }
    if (document.hidden || !visible.has(hero) || reduced.matches) {
      settle();
      art.classList.remove("is-bursting");
    }
  }
  const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) visible.add(entry.target);
      else visible.delete(entry.target);
    }
    update();
  });
  sections.forEach((section) => observer.observe(section));
  document.addEventListener("visibilitychange", update);
  reduced.addEventListener("change", update);
})();
