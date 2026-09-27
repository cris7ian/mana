(() => {
  const button = document.querySelector("[data-copy-command]");
  const command = button?.closest(".brew-install");
  const status = document.querySelector("#brew-copy-status");
  if (!button || !command || !status) return;

  let flashTimer;
  button.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(button.dataset.copyCommand);
      status.textContent = "Homebrew install command copied.";
      command.classList.remove("copy-success");
      void command.offsetWidth;
      command.classList.add("copy-success");
      clearTimeout(flashTimer);
      flashTimer = setTimeout(() => command.classList.remove("copy-success"), 720);
    } catch {
      status.textContent = "Could not copy the command. Select the text to copy it.";
    }
  });
})();
