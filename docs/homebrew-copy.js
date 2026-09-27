(() => {
  const button = document.querySelector("[data-copy-command]");
  const status = document.querySelector("#brew-copy-status");
  if (!button || !status) return;

  button.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(button.dataset.copyCommand);
      status.textContent = "Copied";
    } catch {
      status.textContent = "Copy failed; select the command to copy it.";
    }
  });
})();
